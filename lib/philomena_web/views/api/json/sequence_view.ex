defmodule PhilomenaWeb.Api.Json.SequenceView do
  use PhilomenaWeb, :view

  def render("index.json", %{sequences: sequences, total: total} = assigns) do
    %{
      sequences:
        render_many(sequences, PhilomenaWeb.Api.Json.SequenceView, "sequence.json", assigns),
      total: total
    }
  end

  def render("show.json", %{sequence: sequence} = assigns) do
    %{sequence: render_one(sequence, PhilomenaWeb.Api.Json.SequenceView, "sequence.json", assigns)}
  end

  def render("sequence.json", %{sequence: sequence}) do
    %{
      id: sequence.id,
      title: sequence.title,
      thumbnail_id: sequence.thumbnail_id,
      spoiler_warning: sequence.spoiler_warning,
      description: sequence.description,
      user: sequence.creator.name,
      user_id: sequence.creator_id
    }
  end
end
