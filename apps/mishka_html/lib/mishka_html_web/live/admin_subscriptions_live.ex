defmodule MishkaHtmlWeb.AdminSubscriptionsLive do
  use MishkaHtmlWeb, :live_view

  alias MishkaContent.General.Subscription

  use MishkaHtml.Helpers.LiveCRUD,
      module: MishkaContent.General.Subscription,
      redirect: __MODULE__,
      router: Routes,
      skip_list: ["full_name"]

  @impl true
  def render(assigns) do
    Phoenix.View.render(MishkaHtmlWeb.AdminSubscriptionView, "admin_subscriptions_live.html", assigns)
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Subscription.subscribe()
    Process.send_after(self(), :menu, 100)
    socket =
      assign(socket,
        page_size: 10,
        filters: %{},
        page: 1,
        open_modal: false,
        component: nil,
        page_title: MishkaTranslator.Gettext.dgettext("html_live", "مدیریت اشتراک ها"),
        body_color: "#a29ac3cf",
        subscriptions: Subscription.subscriptions(conditions: {1, 10}, filters: %{})
      )

      {:ok, socket, temporary_assigns: [subscriptions: []]}
  end

  # Live CRUD
  paginate(:subscriptions, user_id: false)

  list_search_and_action()


  @impl true
  def handle_event("delete", %{"id" => id} = _params, socket) do
    socket = case Subscription.delete(id) do
      {:ok, :delete, :subscription, repo_data} ->
        Notif.notify_subscribers(%{id: repo_data.id, msg: MishkaTranslator.Gettext.dgettext("html_live", "یک اشتراک از بخش: %{title} حذف شده است.", title: repo_data.section)})
        subscription_assign(
          socket,
          params: socket.assigns.filters,
          page_size: socket.assigns.page_size,
          page_number: socket.assigns.page,
        )

      {:error, :delete, :forced_to_delete, :subscription} ->
        socket
        |> assign([
          open_modal: true,
          component: MishkaHtmlWeb.Admin.Subscription.DeleteErrorComponent
        ])

      {:error, :delete, type, :subscription} when type in [:uuid, :get_record_by_id] ->
        socket
        |> put_flash(:warning, MishkaTranslator.Gettext.dgettext("html_live", "چنین مجموعه ای وجود ندارد یا ممکن است از قبل حذف شده باشد."))

      {:error, :delete, :subscription, _repo_error} ->
        socket
        |> put_flash(:error, MishkaTranslator.Gettext.dgettext("html_live", "خطا در حذف مجموعه اتفاق افتاده است."))
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:subscription, :ok, repo_record}, socket) do
    socket = case repo_record.__meta__.state do
      :loaded ->
        subscription_assign(
          socket,
          params: socket.assigns.filters,
          page_size: socket.assigns.page_size,
          page_number: socket.assigns.page,
        )
       _ ->  socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:menu, socket) do
    AdminMenu.notify_subscribers({:menu, "Elixir.MishkaHtmlWeb.AdminSubscriptionsLive"})
    {:noreply, socket}
  end

  defp subscription_filter(params) when is_map(params) do
    Map.take(params, Subscription.allowed_fields(:string) ++ ["full_name"])
    |> Enum.reject(fn {_key, value} -> value == "" end)
    |> Map.new()
    |> MishkaDatabase.convert_string_map_to_atom_map()
  end

  defp subscription_filter(_params), do: %{}

  defp subscription_assign(socket, params: params, page_size: count, page_number: page) do
    assign(socket,
        [
          subscriptions: Subscription.subscriptions(conditions: {page, count}, filters: subscription_filter(params)),
          page_size: count,
          filters: params,
          page: page
        ]
      )
  end
end
