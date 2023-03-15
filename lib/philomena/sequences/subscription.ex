defmodule Philomena.Sequences.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Sequences.Sequence
  alias Philomena.Users.User

  @primary_key false

  schema "sequence_subscriptions" do
    belongs_to :sequence, Sequence, primary_key: true
    belongs_to :user, User, primary_key: true
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [])
    |> validate_required([])
  end
end
