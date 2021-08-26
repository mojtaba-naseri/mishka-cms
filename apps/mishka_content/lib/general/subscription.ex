defmodule MishkaContent.General.Subscription do
  alias MishkaDatabase.Schema.MishkaContent.Subscription

  import Ecto.Query
  use MishkaDatabase.CRUD,
          module: Subscription,
          error_atom: :subscription,
          repo: MishkaDatabase.Repo

  @type data_uuid() :: Ecto.UUID.t
  @type record_input() :: map()
  @type error_tag() :: :subscription
  @type repo_data() :: Ecto.Schema.t()
  @type repo_error() :: Ecto.Changeset.t()

  @behaviour MishkaDatabase.CRUD

  def subscribe do
    Phoenix.PubSub.subscribe(MishkaHtml.PubSub, "subscription")
  end

  @spec create(record_input()) ::
  {:error, :add, error_tag(), repo_error()} | {:ok, :add, error_tag(), repo_data()}
  def create(attrs) do
    crud_add(attrs)
    |> notify_subscribers(:subscription)
  end

  @spec edit(record_input()) ::
  {:error, :edit, :uuid, error_tag()} |
  {:error, :edit, :get_record_by_id, error_tag()} |
  {:error, :edit, error_tag(), repo_error()} | {:ok, :edit, error_tag(), repo_data()}
  def edit(attrs) do
    crud_edit(attrs)
    |> notify_subscribers(:subscription)
  end

  @spec delete(data_uuid()) ::
  {:error, :delete, :uuid, error_tag()} |
  {:error, :delete, :get_record_by_id, error_tag()} |
  {:error, :delete, :forced_to_delete, error_tag()} |
  {:error, :delete, error_tag(), repo_error()} | {:ok, :delete, error_tag(), repo_data()}
  def delete(id) do
    crud_delete(id)
    |> notify_subscribers(:subscription)
  end

  @spec delete(data_uuid(), data_uuid()) ::
          {:error, :delete, :forced_to_delete | :get_record_by_id | :subscription | :uuid,
           :not_found | :subscription | Ecto.Changeset.t()}
          | {:ok, :delete, :subscription, %{optional(atom) => any}}
  def delete(user_id, section_id) do
    from(sub in Subscription, where: sub.user_id == ^user_id and sub.section_id == ^section_id)
    |> MishkaDatabase.Repo.one()
    |> case do
      nil -> {:error, :delete, :subscription, :not_found}
      comment -> delete(comment.id)
    end
  rescue
    Ecto.Query.CastError -> {:error, :delete, :subscription, :not_found}
  end

  @spec show_by_id(data_uuid()) ::
          {:error, :get_record_by_id, error_tag()} | {:ok, :get_record_by_id, error_tag(), repo_data()}
  def show_by_id(id) do
    crud_get_record(id)
  end


  @spec subscriptions([{:conditions, {integer() | String.t(), integer() | String.t()}} | {:filters, map()}, ...]) :: Scrivener.Page.t()
  def subscriptions(conditions: {page, page_size}, filters: filters) do
    from(sub in Subscription, join: user in assoc(sub, :users)) |> convert_filters_to_where(filters)
    |> fields()
    |> MishkaDatabase.Repo.paginate(page: page, page_size: page_size)
  rescue
    Ecto.Query.CastError ->
      %Scrivener.Page{entries: [], page_number: 1, page_size: page_size, total_entries: 0,total_pages: 1}
  end

  defp convert_filters_to_where(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, query ->
      case key do
        :full_name ->
          like = "%#{value}%"
          from([sub, user] in query, where: like(user.full_name, ^like))

        _ -> from [sub, user] in query, where: field(sub, ^key) == ^value
      end
    end)
  end

  defp fields(query) do
    from [sub, user] in query,
    order_by: [desc: sub.inserted_at, desc: sub.id],
    select: %{
      id: sub.id,
      status: sub.status,
      section: sub.section,
      section_id: sub.section_id,
      expire_time: sub.expire_time,
      extra: sub.extra,
      user_full_name: user.full_name,
      user_id: user.id,
      username: user.username,
      inserted_at: sub.inserted_at,
      updated_at: sub.updated_at
    }
  end

  @spec allowed_fields(:atom | :string) :: nil | list
  def allowed_fields(:atom), do: Subscription.__schema__(:fields)
  def allowed_fields(:string), do: Subscription.__schema__(:fields) |> Enum.map(&Atom.to_string/1)

  @spec notify_subscribers(tuple(), atom() | String.t()) :: tuple() | map()
  def notify_subscribers({:ok, _, :subscription, repo_data} = params, type_send) do
    Phoenix.PubSub.broadcast(MishkaHtml.PubSub, "subscription", {type_send, :ok, repo_data})
    params
  end

  def notify_subscribers(params, _), do: params
end
