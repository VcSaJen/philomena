defmodule PhilomenaWeb.SequenceController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias PhilomenaWeb.NotificationCountPlug
  alias Philomena.Elasticsearch
  alias Philomena.Interactions
  alias Philomena.Sequences.Sequence
  alias Philomena.Sequences
  alias Philomena.Images.Image
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create, :edit, :update, :delete]
  plug PhilomenaWeb.MapParameterPlug, [param: "sequence"] when action in [:index]

  plug :load_and_authorize_resource,
       model: Sequence,
       except: [:index],
       preload: [:creator, thumbnail: [tags: :aliases]]

  def index(conn, params) do
    sequences =
      Sequence
      |> Elasticsearch.search_definition(
           %{
             query: %{
               bool: %{
                 must: parse_search(params)
               }
             },
             sort: parse_sort(params)
           },
           conn.assigns.pagination
         )
      |> Elasticsearch.search_records(preload(Sequence, [:creator, thumbnail: [tags: :aliases]]))

    render(conn, "index.html",
      title: "Sequences",
      sequences: sequences,
      layout_class: "layout--wide"
    )
  end

  def show(conn, _params) do
    sequence = conn.assigns.sequence
    user = conn.assigns.current_user
    query = "sequence_id:#{sequence.id}"

    conn =
      update_in(
        conn.params,
        &Map.merge(&1, %{
          "q" => query,
          "sf" => "sequence_id:#{sequence.id}",
          "sd" => position_order(sequence)
        })
      )

    {:ok, {images, _tags}} = ImageLoader.search_string(conn, query)
    {sequence_prev, sequence_next} = prev_next_page_images(conn, query)

    [images, sequence_prev, sequence_next] =
      Elasticsearch.msearch_records_with_hits(
        [images, sequence_prev, sequence_next],
        [
          preload(Image, tags: :aliases),
          preload(Image, tags: :aliases),
          preload(Image, tags: :aliases)
        ]
      )

    interactions = Interactions.user_interactions([images, sequence_prev, sequence_next], user)

    watching = Sequences.subscribed?(sequence, user)

    sequence_images =
      Enum.to_list(sequence_prev) ++ Enum.to_list(images) ++ Enum.to_list(sequence_next)

    sequence_json = Jason.encode!(Enum.map(sequence_images, &elem(&1, 0).id))

    Sequences.clear_notification(sequence, user)

    conn
    |> NotificationCountPlug.call([])
    |> assign(:clientside_data, sequence_images: sequence_json)
    |> render("show.html",
         title: "Showing Sequence",
         layout_class: "layout--wide",
         watching: watching,
         sequence: sequence,
         sequence_prev: Enum.any?(sequence_prev),
         sequence_next: Enum.any?(sequence_next),
         sequence_images: sequence_images,
         images: images,
         interactions: interactions
       )
  end

  def new(conn, _params) do
    changeset = Sequences.change_sequence(%Sequence{})
    render(conn, "new.html", title: "New Sequence", changeset: changeset)
  end

  def create(conn, %{"sequence" => sequence_params}) do
    user = conn.assigns.current_user

    case Sequences.create_sequence(user, sequence_params) do
      {:ok, sequence} ->
        conn
        |> put_flash(:info, "Sequence successfully created.")
        |> redirect(to: Routes.sequence_path(conn, :show, sequence))

      {:error, changeset} ->
        conn
        |> render("new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    sequence = conn.assigns.sequence
    changeset = Sequences.change_sequence(sequence)

    render(conn, "edit.html", title: "Editing Sequence", sequence: sequence, changeset: changeset)
  end

  def update(conn, %{"sequence" => sequence_params}) do
    sequence = conn.assigns.sequence

    case Sequences.update_sequence(sequence, sequence_params) do
      {:ok, sequence} ->
        conn
        |> put_flash(:info, "Sequence successfully updated.")
        |> redirect(to: Routes.sequence_path(conn, :show, sequence))

      {:error, changeset} ->
        conn
        |> render("edit.html", sequence: sequence, changeset: changeset)
    end
  end

  def delete(conn, _params) do
    sequence = conn.assigns.sequence

    {:ok, _sequence} = Sequences.delete_sequence(sequence)

    conn
    |> put_flash(:info, "Sequence successfully destroyed.")
    |> redirect(to: Routes.sequence_path(conn, :index))
  end

  defp prev_next_page_images(conn, query) do
    limit = conn.assigns.image_pagination.page_size
    offset = (conn.assigns.image_pagination.page_number - 1) * limit

    # Inconsistency: Elasticsearch doesn't allow requesting offsets which are less than 0,
    # but it does allow requesting offsets which are beyond the total number of results.

    prev_image = sequence_image(offset - 1, conn, query)
    next_image = sequence_image(offset + limit, conn, query)

    {prev_image, next_image}
  end

  defp sequence_image(offset, _conn, _query) when offset < 0 do
    Elasticsearch.search_definition(Image, %{query: %{match_none: %{}}})
  end

  defp sequence_image(offset, conn, query) do
    pagination_params = %{page_number: offset + 1, page_size: 1}

    {:ok, {image, _tags}} = ImageLoader.search_string(conn, query, pagination: pagination_params)

    image
  end

  defp parse_search(%{"sequence" => sequence_params}) do
    parse_title(sequence_params) ++
    parse_creator(sequence_params) ++
    parse_included_image(sequence_params) ++
    parse_description(sequence_params)
  end

  defp parse_search(_params), do: [%{match_all: %{}}]

  defp parse_title(%{"title" => title}) when is_binary(title) and title not in [nil, ""],
       do: [%{wildcard: %{title: "*" <> String.downcase(title) <> "*"}}]

  defp parse_title(_params), do: []

  defp parse_creator(%{"creator" => creator})
       when is_binary(creator) and creator not in [nil, ""],
       do: [%{term: %{creator: String.downcase(creator)}}]

  defp parse_creator(_params), do: []

  defp parse_included_image(%{"include_image" => image_id})
       when is_binary(image_id) and image_id not in [nil, ""] do
    with {image_id, _rest} <- Integer.parse(image_id) do
      [%{term: %{image_ids: image_id}}]
    else
      _ ->
        []
    end
  end

  defp parse_included_image(_params), do: []

  defp parse_description(%{"description" => description})
       when is_binary(description) and description not in [nil, ""],
       do: [%{match_phrase: %{description: description}}]

  defp parse_description(_params), do: []

  defp parse_sort(%{"sequence" => %{"sf" => sf, "sd" => sd}})
       when sf in ["created_at", "updated_at", "image_count", "_score"] and
            sd in ["desc", "asc"] do
    %{sf => sd}
  end

  defp parse_sort(_params) do
    %{created_at: :desc}
  end

  defp position_order(%{order_position_asc: true}), do: "asc"
  defp position_order(_sequence), do: "desc"
end
