defmodule Philomena.Sequences.Interaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Sequences.Sequence
  alias Philomena.Images.Image

  # fixme: unique-key this off (sequence_id, image_id)
  schema "sequence_interactions" do
    belongs_to :sequence, Sequence
    belongs_to :image, Image

    field :position, :integer
  end

  @doc false
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:image_id, :position])
    |> validate_required([:image_id, :position])
    |> foreign_key_constraint(:image_id, name: :sequence_interactions_image_id_fkey)
    |> unique_constraint(:image_id, name: :index_sequence_interactions_on_sequence_id_and_image_id)
    |> case do
      %{valid?: false, changes: changes} = changeset when changes == %{} ->
        %{changeset | action: :ignore}

      changeset ->
        changeset
    end
  end
end
