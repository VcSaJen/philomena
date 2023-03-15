defmodule PhilomenaWeb.Sequence.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Sequences.Sequence
  alias Philomena.Reports.Report
  alias Philomena.Reports

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]
  plug PhilomenaWeb.CanaryMapPlug, new: :show, create: :show

  plug :load_and_authorize_resource,
       model: Sequence,
       id_name: "sequence_id",
       persisted: true,
       preload: [:creator]

  def new(conn, _params) do
    sequence = conn.assigns.sequence
    action = Routes.sequence_report_path(conn, :create, sequence)

    changeset =
      %Report{reportable_type: "Sequence", reportable_id: sequence.id}
      |> Reports.change_report()

    conn
    |> put_view(ReportView)
    |> render("new.html",
         title: "Reporting Sequence",
         reportable: sequence,
         changeset: changeset,
         action: action
       )
  end

  def create(conn, params) do
    sequence = conn.assigns.sequence
    action = Routes.sequence_report_path(conn, :create, sequence)

    ReportController.create(conn, action, sequence, "Sequence", params)
  end
end
