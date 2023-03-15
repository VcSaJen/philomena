defmodule PhilomenaWeb.Sequence.OrderController do
  use PhilomenaWeb, :controller

  alias Philomena.Sequences.Sequence
  alias Philomena.Sequences

  plug PhilomenaWeb.FilterBannedUsersPlug

  plug PhilomenaWeb.CanaryMapPlug, update: :edit
  plug :load_and_authorize_resource, model: Sequence, id_name: "sequence_id", persisted: true

  def update(conn, %{"image_ids" => image_ids}) when is_list(image_ids) do
    sequence = conn.assigns.sequence

    Sequences.reorder_sequence(sequence, image_ids)

    json(conn, %{})
  end
end
