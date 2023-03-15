defmodule PhilomenaWeb.Sequence.SubscriptionController do
  use PhilomenaWeb, :controller

  alias Philomena.Sequences.Sequence
  alias Philomena.Sequences

  plug PhilomenaWeb.CanaryMapPlug, create: :show, delete: :show
  plug :load_and_authorize_resource, model: Sequence, id_name: "sequence_id", persisted: true

  def create(conn, _params) do
    sequence = conn.assigns.sequence
    user = conn.assigns.current_user

    case Sequences.create_subscription(sequence, user) do
      {:ok, _subscription} ->
        render(conn, "_subscription.html", sequence: sequence, watching: true, layout: false)

      {:error, _changeset} ->
        render(conn, "_error.html", layout: false)
    end
  end

  def delete(conn, _params) do
    sequence = conn.assigns.sequence
    user = conn.assigns.current_user

    case Sequences.delete_subscription(sequence, user) do
      {:ok, _subscription} ->
        render(conn, "_subscription.html", sequence: sequence, watching: false, layout: false)

      {:error, _changeset} ->
        render(conn, "_error.html", layout: false)
    end
  end
end
