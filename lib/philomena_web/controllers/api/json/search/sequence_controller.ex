defmodule PhilomenaWeb.Api.Json.Search.SequenceController do
  use PhilomenaWeb, :controller

  alias Philomena.Elasticsearch
  alias Philomena.Sequences.Sequence
  alias Philomena.Sequences.Query
  import Ecto.Query

  def index(conn, params) do
    case Query.compile(params["q"] || "") do
      {:ok, query} ->
        sequences =
          Sequence
          |> Elasticsearch.search_definition(
               %{
                 query: query,
                 sort: %{created_at: :desc}
               },
               conn.assigns.pagination
             )
          |> Elasticsearch.search_records(preload(Sequence, [:creator]))

        conn
        |> put_view(PhilomenaWeb.Api.Json.SequenceView)
        |> render("index.json", sequences: sequences, total: sequences.total_entries)

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
