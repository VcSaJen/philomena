defmodule Philomena.NotificationWorker do
  @modules %{
    "Comments" => Philomena.Comments,
    "Galleries" => Philomena.Galleries,
    "Sequences" => Philomena.Sequences,
    "Images" => Philomena.Images,
    "Posts" => Philomena.Posts,
    "Topics" => Philomena.Topics
  }

  def perform(module, args) do
    @modules[module].perform_notify(args)
  end
end
