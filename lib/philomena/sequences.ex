defmodule Philomena.Sequences do
  @moduledoc """
  The Sequences context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Elasticsearch
  alias Philomena.Sequences.Sequence
  alias Philomena.Sequences.Interaction
  alias Philomena.Sequences.ElasticsearchIndex, as: SequenceIndex
  alias Philomena.IndexWorker
  alias Philomena.SequenceReorderWorker
  alias Philomena.Notifications
  alias Philomena.NotificationWorker
  alias Philomena.Images

  @doc """
  Gets a single sequence.

  Raises `Ecto.NoResultsError` if the Sequence does not exist.

  ## Examples

      iex> get_sequence!(123)
      %Sequence{}

      iex> get_sequence!(456)
      ** (Ecto.NoResultsError)

  """
  def get_sequence!(id), do: Repo.get!(Sequence, id)

  @doc """
  Creates a sequence.

  ## Examples

      iex> create_sequence(%{field: value})
      {:ok, %Sequence{}}

      iex> create_sequence(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_sequence(user, attrs \\ %{}) do
    %Sequence{}
    |> Sequence.creation_changeset(attrs, user)
    |> Repo.insert()
    |> reindex_after_update()
  end

  @doc """
  Updates a sequence.

  ## Examples

      iex> update_sequence(sequence, %{field: new_value})
      {:ok, %Sequence{}}

      iex> update_sequence(sequence, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_sequence(%Sequence{} = sequence, attrs) do
    sequence
    |> Sequence.changeset(attrs)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Deletes a Sequence.

  ## Examples

      iex> delete_sequence(sequence)
      {:ok, %Sequence{}}

      iex> delete_sequence(sequence)
      {:error, %Ecto.Changeset{}}

  """
  def delete_sequence(%Sequence{} = sequence) do
    images =
      Interaction
      |> where(sequence_id: ^sequence.id)
      |> select([i], i.image_id)
      |> Repo.all()

    Repo.delete(sequence)
    |> case do
         {:ok, sequence} ->
           unindex_sequence(sequence)
           Images.reindex_images(images)

           {:ok, sequence}

         error ->
           error
       end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking sequence changes.

  ## Examples

      iex> change_sequence(sequence)
      %Ecto.Changeset{source: %Sequence{}}

  """
  def change_sequence(%Sequence{} = sequence) do
    Sequence.changeset(sequence, %{})
  end

  def user_name_reindex(old_name, new_name) do
    data = SequenceIndex.user_name_update_by_query(old_name, new_name)

    Elasticsearch.update_by_query(Sequence, data.query, data.set_replacements, data.replacements)
  end

  defp reindex_after_update({:ok, sequence}) do
    reindex_sequence(sequence)

    {:ok, sequence}
  end

  defp reindex_after_update(error) do
    error
  end

  def reindex_sequence(%Sequence{} = sequence) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Sequences", "id", [sequence.id]])

    sequence
  end

  def unindex_sequence(%Sequence{} = sequence) do
    Elasticsearch.delete_document(sequence.id, Sequence)

    sequence
  end

  def indexing_preloads do
    [:subscribers, :creator, :interactions]
  end

  def perform_reindex(column, condition) do
    Sequence
    |> preload(^indexing_preloads())
    |> where([s], field(s, ^column) in ^condition)
    |> Elasticsearch.reindex(Sequence)
  end

  def add_image_to_sequence(sequence, image) do
    Multi.new()
    |> Multi.run(:lock, fn repo, %{} ->
      sequence =
        Sequence
        |> where(id: ^sequence.id)
        |> lock("FOR UPDATE")
        |> repo.one()

      {:ok, sequence}
    end)
    |> Multi.run(:interaction, fn repo, %{} ->
      position = (last_position(sequence.id) || -1) + 1

      %Interaction{sequence_id: sequence.id}
      |> Interaction.changeset(%{"image_id" => image.id, "position" => position})
      |> repo.insert()
    end)
    |> Multi.run(:sequence, fn repo, %{} ->
      now = DateTime.utc_now()

      {count, nil} =
        Sequence
        |> where(id: ^sequence.id)
        |> repo.update_all(inc: [image_count: 1], set: [updated_at: now])

      {:ok, count}
    end)
    |> Repo.transaction()
    |> case do
         {:ok, result} ->
           Images.reindex_image(image)
           notify_sequence(sequence)
           reindex_sequence(sequence)

           {:ok, result}

         error ->
           error
       end
  end

  def remove_image_from_sequence(sequence, image) do
    Multi.new()
    |> Multi.run(:lock, fn repo, %{} ->
      sequence =
        Sequence
        |> where(id: ^sequence.id)
        |> lock("FOR UPDATE")
        |> repo.one()

      {:ok, sequence}
    end)
    |> Multi.run(:interaction, fn repo, %{} ->
      {count, nil} =
        Interaction
        |> where(sequence_id: ^sequence.id, image_id: ^image.id)
        |> repo.delete_all()

      {:ok, count}
    end)
    |> Multi.run(:sequence, fn repo, %{interaction: interaction_count} ->
      now = DateTime.utc_now()

      {count, nil} =
        Sequence
        |> where(id: ^sequence.id)
        |> repo.update_all(inc: [image_count: -interaction_count], set: [updated_at: now])

      {:ok, count}
    end)
    |> Repo.transaction()
    |> case do
         {:ok, result} ->
           Images.reindex_image(image)
           reindex_sequence(sequence)

           {:ok, result}

         error ->
           error
       end
  end

  defp last_position(sequence_id) do
    Interaction
    |> where(sequence_id: ^sequence_id)
    |> Repo.aggregate(:max, :position)
  end

  def notify_sequence(sequence) do
    Exq.enqueue(Exq, "notifications", NotificationWorker, ["Sequences", sequence.id])
  end

  def perform_notify(sequence_id) do
    sequence = get_sequence!(sequence_id)

    subscriptions =
      sequence
      |> Repo.preload(:subscriptions)
      |> Map.fetch!(:subscriptions)

    Notifications.notify(
      sequence,
      subscriptions,
      %{
        actor_id: sequence.id,
        actor_type: "Sequence",
        actor_child_id: nil,
        actor_child_type: nil,
        action: "added images to"
      }
    )
  end

  def reorder_sequence(sequence, image_ids) do
    Exq.enqueue(Exq, "indexing", SequenceReorderWorker, [sequence.id, image_ids])
  end

  def perform_reorder(sequence_id, image_ids) do
    sequence = get_sequence!(sequence_id)

    interactions =
      Interaction
      |> where([si], si.image_id in ^image_ids and si.sequence_id == ^sequence.id)
      |> order_by(^position_order(sequence))
      |> Repo.all()

    interaction_positions =
      interactions
      |> Enum.with_index()
      |> Map.new(fn {interaction, index} -> {index, interaction.position} end)

    images_present = Map.new(interactions, &{&1.image_id, true})

    requested =
      image_ids
      |> Enum.filter(&images_present[&1])
      |> Enum.with_index()
      |> Map.new()

    changes =
      interactions
      |> Enum.with_index()
      |> Enum.flat_map(fn {interaction, current_index} ->
        new_index = requested[interaction.image_id]

        case new_index == current_index do
          true ->
            []

          false ->
            [
              [
                id: interaction.id,
                position: interaction_positions[new_index]
              ]
            ]
        end
      end)

    changes
    |> Enum.map(fn change ->
      id = Keyword.fetch!(change, :id)
      change = Keyword.delete(change, :id)

      Interaction
      |> where([i], i.id == ^id)
      |> Repo.update_all(set: change)
    end)

    # Do the update in a single statement
    # Repo.insert_all(
    #   Interaction,
    #   changes,
    #   on_conflict: {:replace, [:position]},
    #   conflict_target: [:id]
    # )

    # Now update all the associated images
    Images.reindex_images(Map.keys(requested))
  end

  defp position_order(%{order_position_asc: true}), do: [asc: :position]
  defp position_order(_sequence), do: [desc: :position]

  alias Philomena.Sequences.Subscription

  def subscribed?(_sequence, nil), do: false

  def subscribed?(sequence, user) do
    Subscription
    |> where(sequence_id: ^sequence.id, user_id: ^user.id)
    |> Repo.exists?()
  end

  @doc """
  Creates a subscription.

  ## Examples

      iex> create_subscription(%{field: value})
      {:ok, %Subscription{}}

      iex> create_subscription(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_subscription(sequence, user) do
    %Subscription{sequence_id: sequence.id, user_id: user.id}
    |> Subscription.changeset(%{})
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Deletes a Subscription.

  ## Examples

      iex> delete_subscription(subscription)
      {:ok, %Subscription{}}

      iex> delete_subscription(subscription)
      {:error, %Ecto.Changeset{}}

  """
  def delete_subscription(sequence, user) do
    %Subscription{sequence_id: sequence.id, user_id: user.id}
    |> Repo.delete()
  end

  def clear_notification(_sequence, nil), do: nil

  def clear_notification(sequence, user) do
    Notifications.delete_unread_notification("Sequence", sequence.id, user)
  end
end
