defmodule AgPhx.Firestore.DAO do
  @moduledoc false
  alias GoogleApi.Firestore.V1.Api.Projects
  alias GoogleApi.Firestore.V1.Connection
  alias GoogleApi.Firestore.V1.Model.BeginTransactionResponse
  require Logger
  @datastore_auth_request_url "https://www.googleapis.com/auth/datastore"
  def begin_transaction(conn, database) do
    Projects.firestore_projects_databases_documents_begin_transaction(
      conn,
      database
    )
    |> case do
      {:ok, %BeginTransactionResponse{transaction: transaction}} ->
        {:ok, transaction}

      error ->
        Logger.error("error #{inspect(error)}")
        {:error, :begin_transaction_failure}
    end
  end

  def prepare_commit_request(document, transaction) do
    request = %GoogleApi.Firestore.V1.Model.CommitRequest{
      transaction: transaction,
      writes: [
        %GoogleApi.Firestore.V1.Model.Write{
          update: document
        }
      ]
    }

    {:ok, request}
  end

  def commit(conn, database, request) do
    Projects.firestore_projects_databases_documents_commit(
      conn,
      database,
      body: request
    )
    |> case do
      {:ok, _} ->
        {:ok, :delivery_details_persisted}

      err ->
        Logger.error("error #{inspect(err)}")
        {:error, :delivery_details_persistance_failure}
    end
  end

  def save(project, document) do
    database = "projects/#{project}/databases/(default)"

    with {:ok, token} <- Goth.fetch(AgPhx.Goth),
         conn <- Connection.new(token.token),
         {:ok, transaction} <- begin_transaction(conn, database),
         {:ok, request} <- prepare_commit_request(document, transaction),
         {:ok, :delivery_details_persisted} <- commit(conn, database, request) do
      {:ok, :entity_saved}
    else
      {:error, res} ->
        Logger.error("#{inspect(res)}")
        {:error, :datastore_persist_entity_failure}

      err ->
        Logger.error("#{inspect(err)}")
        {:error, :datastore_persist_entity_failure}
    end
  end
end
