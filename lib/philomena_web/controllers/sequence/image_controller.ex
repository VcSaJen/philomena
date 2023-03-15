defmodule PhilomenaWeb.Sequence.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Sequences.Sequence
  alias Philomena.Sequences
  alias Philomena.Images.Image

  plug PhilomenaWeb.FilterBannedUsersPlug

  plug PhilomenaWeb.CanaryMapPlug, create: :edit, delete: :edit
  plug :load_and_authorize_resource, model: Sequence, id_name: "sequence_id", persisted: true

  plug PhilomenaWeb.CanaryMapPlug, create: :show, delete: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, _params) do
    case Sequences.add_image_to_sequence(conn.assigns.sequence, conn.assigns.image) do
      {:ok, _sequence} ->
        json(conn, %{})

      _error ->
        conn
        |> put_status(:bad_request)
        |> json(%{})
    end
  end

  def delete(conn, _params) do
    case Sequences.remove_image_from_sequence(conn.assigns.sequence, conn.assigns.image) do
      {:ok, _sequence} ->
        json(conn, %{})

      _error ->
        conn
        |> put_status(:bad_request)
        |> json(%{})
    end
  end
end
