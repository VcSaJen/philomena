defmodule PhilomenaWeb.Sequence.ReadController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Sequences.Sequence
  alias Philomena.Sequences

  plug :load_resource, model: Sequence, id_name: "sequence_id", persisted: true

  def create(conn, _params) do
    sequence = conn.assigns.sequence
    user = conn.assigns.current_user

    Sequences.clear_notification(sequence, user)

    send_resp(conn, :ok, "")
  end
end
