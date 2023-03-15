defmodule Philomena.SequenceReorderWorker do
  alias Philomena.Sequences

  def perform(sequence_id, image_ids) do
    Sequences.perform_reorder(sequence_id, image_ids)
  end
end
