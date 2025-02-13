defmodule MishkaHtmlWeb.Client.Public.HeaderComponent do
  use MishkaHtmlWeb, :live_component

  def render(assigns) do
    ~H"""
      <header class="col mx-auto client-header vazir">
        <div class="py-5 text-center">
        <img class="d-block mx-auto mb-4" src={Routes.static_path(@socket, "/images/mylogo.png")} alt="" width="198" height="136">
        <div class="space10"></div>
        </div>

        <%= live_render(@socket, MishkaHtmlWeb.Client.Public.ClientMenuAndNotif, id: :client_menu_and_notif) %>
      </header>
    """
  end
end
