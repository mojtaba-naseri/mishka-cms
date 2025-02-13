defmodule MishkaHtmlWeb.AdminBlogPostLive do
  use MishkaHtmlWeb, :live_view
  alias MishkaContent.Cache.ContentDraftManagement
  alias MishkaContent.Blog.{Post, Category}
  alias MishkaContent.General.Subscription

  @error_atom :post

  use MishkaHtml.Helpers.LiveCRUD,
    module: MishkaContent.Blog.Post,
    redirect: __MODULE__,
    router: Routes

  @impl true
  def render(assigns) do
    Phoenix.View.render(MishkaHtmlWeb.AdminBlogView, "admin_blog_post_live.html", assigns)
  end

  @impl true
  def mount(_params, session, socket) do
    Process.send_after(self(), :menu, 100)

    socket =
      assign(socket,
        dynamic_form: [],
        page_title: MishkaTranslator.Gettext.dgettext("html_live", "مدیریت ساخت مطلب"),
        body_color: "#a29ac3cf",
        basic_menu: false,
        options_menu: false,
        tags: [],
        editor: nil,
        id: nil,
        user_id: Map.get(session, "user_id"),
        drafts: ContentDraftManagement.drafts_by_section(section: "post"),
        draft_id: nil,
        category_id: nil,
        images: {nil, nil},
        alias_link: nil,
        category_search: [],
        changeset: post_changeset()
      )
      |> assign(:uploaded_files, [])
      |> allow_upload(:main_image_upload,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 1,
        max_file_size: 10_000_000,
        auto_upload: true
      )
      |> allow_upload(:header_image_upload,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 1,
        max_file_size: 10_000_000,
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    all_field = create_menu_list(basic_menu_list() ++ more_options_menu_list(), [])

    socket =
      case Post.show_by_id(id) do
        {:error, :get_record_by_id, @error_atom} ->
          socket
          |> put_flash(
            :warning,
            MishkaTranslator.Gettext.dgettext(
              "html_live",
              "چنین مطلبی وجود ندارد یا ممکن است از قبل حذف شده باشد."
            )
          )
          |> push_redirect(to: Routes.live_path(socket, MishkaHtmlWeb.AdminBlogPostsLive))

        {:ok, :get_record_by_id, @error_atom, repo_data} ->
          posts =
            Enum.map(all_field, fn field ->
              record =
                Enum.find(creata_post_state(repo_data), fn post -> post.type == field.type end)

              Map.merge(field, %{value: if(is_nil(record), do: nil, else: record.value)})
            end)
            |> Enum.reject(fn x -> x.value == nil end)

          get_tag = Enum.find(posts, fn post -> post.type == "meta_keywords" end)
          description = Enum.find(posts, fn post -> post.type == "description" end)

          socket
          |> assign(
            dynamic_form: posts,
            tags:
              if(is_nil(get_tag),
                do: [],
                else: if(is_nil(get_tag.value), do: [], else: String.split(get_tag.value, ","))
              ),
            id: repo_data.id,
            images: {repo_data.main_image, repo_data.header_image},
            alias_link: repo_data.alias_link,
            category_id: repo_data.category_id
          )
          |> push_event("update-editor-html", %{html: description.value})
      end

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # Live CRUD
  basic_menu()

  options_menu()

  save_editor("post")

  delete_form()

  make_all_basic_menu()

  clear_all_field(post_changeset())

  make_all_menu()

  editor_draft(
    "post",
    true,
    [
      {:category_search, Category, :search_category_title, "category_id", 5}
    ],
    when_not: ["main_image", "main_image"]
  )

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref, "upload_field" => field} = _params, socket) do
    {:noreply, cancel_upload(socket, String.to_atom(field), ref)}
  end

  @impl true
  def handle_event("set_tag", %{"key" => "Enter", "value" => value}, socket) do
    new_socket =
      case Enum.any?(socket.assigns.tags, fn tag -> tag == value end) do
        true ->
          socket

        false ->
          socket
          |> assign(tags: [value] ++ socket.assigns.tags)
      end

    {:noreply, new_socket}
  end

  @impl true
  def handle_event("delete_tag", %{"tag" => value}, socket) do
    socket =
      socket
      |> assign(:tags, Enum.reject(socket.assigns.tags, fn tag -> tag == value end))

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_link", %{"key" => "Enter", "value" => value}, socket) do
    alias_link = MishkaHtml.create_alias_link(value)

    socket =
      socket
      |> assign(:alias_link, alias_link)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_image", %{"type" => type}, socket) do
    {main_image, header_image} = socket.assigns.images

    image = if(type == "main_image", do: main_image, else: header_image)

    Path.join([:code.priv_dir(:mishka_html), "static", image])
    |> File.rm()

    socket =
      socket
      |> assign(
        :images,
        if(type == "main_image", do: {nil, header_image}, else: {main_image, nil})
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"post" => params}, socket) do
    socket =
      case MishkaHtml.html_form_required_fields(basic_menu_list(), params) do
        [] ->
          socket

        fields_list ->
          socket
          |> put_flash(:info, MishkaTranslator.Gettext.dgettext("html_live", "
        متاسفانه شما چند فیلد ضروری را به لیست خود اضافه نکردید از جمله:
         (%{tag_list})
         برای اضافه کردن تمامی نیازمندی ها روی دکمه
         \"فیلد های ضروری\"
          کلیک کنید
         ", tag_list: MishkaHtml.list_tag_to_string(fields_list, ", ")))
      end

    uploaded_main_image_files = upload(socket, :main_image_upload)
    uploaded_header_image_files = upload(socket, :header_image_upload)

    meta_keywords = MishkaHtml.list_tag_to_string(socket.assigns.tags, ", ")

    case socket.assigns.id do
      nil ->
        create_post(socket,
          params: {
            params,
            if(meta_keywords == "", do: nil, else: meta_keywords),
            if(uploaded_main_image_files != [],
              do: List.first(uploaded_main_image_files),
              else: nil
            ),
            if(uploaded_header_image_files != [],
              do: List.first(uploaded_header_image_files),
              else: nil
            ),
            if(is_nil(socket.assigns.editor), do: nil, else: socket.assigns.editor),
            socket.assigns.alias_link,
            socket.assigns.category_id
          },
          uploads: {uploaded_main_image_files, uploaded_header_image_files}
        )

      id ->
        edit_post(socket,
          params: {
            params,
            if(meta_keywords == "", do: nil, else: meta_keywords),
            if(uploaded_main_image_files != [],
              do: List.first(uploaded_main_image_files),
              else: nil
            ),
            if(uploaded_header_image_files != [],
              do: List.first(uploaded_header_image_files),
              else: nil
            ),
            if(is_nil(socket.assigns.editor), do: nil, else: socket.assigns.editor),
            id,
            socket.assigns.alias_link,
            socket.assigns.category_id
          },
          uploads: {uploaded_main_image_files, uploaded_header_image_files}
        )
    end
  end

  @impl true
  def handle_event("save", _params, socket) do
    socket =
      case MishkaHtml.html_form_required_fields(basic_menu_list(), []) do
        [] ->
          socket

        fields_list ->
          socket
          |> put_flash(:info, MishkaTranslator.Gettext.dgettext("html_live", "
        متاسفانه شما چند فیلد ضروری را به لیست خود اضافه نکردید از جمله:
         (%{tag_list})
         برای اضافه کردن تمامی نیازمندی ها روی دکمه
         \"فیلد های ضروری\"
          کلیک کنید
         ", tag_list: MishkaHtml.list_tag_to_string(fields_list, ", ")))
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("text_search_click", %{"id" => id}, socket) do
    socket =
      socket
      |> assign(
        category_id: id,
        category_search: []
      )
      |> push_event("update_text_search", %{value: id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_text_search", _, socket) do
    socket =
      socket
      |> assign(category_search: [])

    {:noreply, socket}
  end

  selected_menue("MishkaHtmlWeb.AdminBlogPostLive")

  def search_fields(type) do
    Enum.find(basic_menu_list() ++ more_options_menu_list(), fn x -> x.type == type end)
  end

  defp post_changeset(params \\ %{}) do
    MishkaDatabase.Schema.MishkaContent.Blog.Post.changeset(
      %MishkaDatabase.Schema.MishkaContent.Blog.Post{},
      params
    )
  end

  defp create_post(socket,
         params:
           {params, meta_keywords, main_image, header_image, description, alias_link, category_id},
         uploads: {uploaded_main_image_files, uploaded_header_image_files}
       ) do
    {state_main_image, state_header_image} = socket.assigns.images

    main_image = if is_nil(main_image), do: state_main_image, else: main_image
    header_image = if is_nil(header_image), do: state_header_image, else: header_image

    socket =
      case Post.create(
             Map.merge(params, %{
               "meta_keywords" => meta_keywords,
               "main_image" => main_image,
               "header_image" => header_image,
               "description" => description,
               "alias_link" => alias_link,
               "category_id" => category_id
             })
           ) do
        {:error, :add, :post, repo_error} ->
          socket
          |> assign(
            changeset: repo_error,
            images: {main_image, header_image}
          )

        {:ok, :add, :post, repo_data} ->
          # Send notification to subscribed category users
          blog_category_post_notification(
            repo_data,
            MishkaTranslator.Gettext.dgettext("html_live", "مطلب %{title} منتشر شد",
              title: repo_data.title
            )
          )

          MishkaContent.General.Activity.create_activity_by_start_child(
            %{
              type: "section",
              section: "blog_post",
              section_id: repo_data.id,
              action: "add",
              priority: "medium",
              status: "info"
            },
            %{
              user_action: "live_create_post",
              title: repo_data.title,
              type: "admin",
              user_id: socket.assigns.user_id
            }
          )

          if(!is_nil(Map.get(socket.assigns, :draft_id)),
            do:
              MishkaContent.Cache.ContentDraftManagement.delete_record(
                id: socket.assigns.draft_id
              )
          )

          Notif.notify_subscribers(%{
            id: repo_data.id,
            msg: "مطلب: #{MishkaHtml.title_sanitize(repo_data.title)} درست شده است."
          })

          socket
          |> assign(
            dynamic_form: [],
            basic_menu: false,
            options_menu: false,
            changeset: post_changeset(),
            images: {main_image, header_image}
          )
          |> update(:uploaded_files, &(&1 ++ uploaded_main_image_files))
          |> update(:uploaded_files, &(&1 ++ uploaded_header_image_files))
          |> put_flash(:info, "مطلب مورد نظر به لیست اضافه شد")
          |> push_redirect(to: Routes.live_path(socket, MishkaHtmlWeb.AdminBlogPostsLive))
      end

    {:noreply, socket}
  end

  defp edit_post(socket,
         params:
           {params, meta_keywords, main_image, header_image, description, id, alias_link,
            category_id},
         uploads: {_uploaded_main_image_files, _uploaded_header_image_files}
       ) do
    merge_map =
      %{
        "id" => id,
        "meta_keywords" => meta_keywords,
        "main_image" => main_image,
        "header_image" => header_image,
        "description" => description,
        "alias_link" => alias_link,
        "category_id" => category_id
      }
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> Enum.into(%{})

    merged = Map.merge(params, merge_map)
    {main_image, header_image} = socket.assigns.images

    main_image_exist_file =
      if(Map.has_key?(merged, "main_image"), do: %{}, else: %{"main_image" => main_image})

    header_image_exist_file =
      if(Map.has_key?(merged, "header_image"), do: %{}, else: %{"header_image" => header_image})

    exist_images = Map.merge(main_image_exist_file, header_image_exist_file)

    socket =
      case Post.edit(Map.merge(merged, exist_images)) do
        {:error, :edit, :post, repo_error} ->
          socket
          |> assign(
            changeset: repo_error,
            images: {main_image, header_image}
          )

        {:ok, :edit, :post, repo_data} ->
          # Send notification to subscribed category users
          blog_category_post_notification(
            repo_data,
            MishkaTranslator.Gettext.dgettext("html_live", "مطلب %{title} به روز رسانی مجدد شد",
              title: repo_data.title
            )
          )

          MishkaContent.General.Activity.create_activity_by_start_child(
            %{
              type: "section",
              section: "blog_post",
              section_id: repo_data.id,
              action: "edit",
              priority: "medium",
              status: "info"
            },
            %{
              user_action: "live_edit_post",
              title: repo_data.title,
              type: "admin",
              user_id: socket.assigns.user_id
            }
          )

          if(!is_nil(Map.get(socket.assigns, :draft_id)),
            do:
              MishkaContent.Cache.ContentDraftManagement.delete_record(
                id: socket.assigns.draft_id
              )
          )

          Notif.notify_subscribers(%{
            id: repo_data.id,
            msg: "مطلب: #{MishkaHtml.title_sanitize(repo_data.title)} به روز شده است."
          })

          socket
          |> put_flash(
            :info,
            MishkaTranslator.Gettext.dgettext("html_live", "مطلب به روز رسانی شد")
          )
          |> push_redirect(to: Routes.live_path(socket, MishkaHtmlWeb.AdminBlogPostsLive))

        {:error, :edit, :uuid, _error_tag} ->
          socket
          |> put_flash(
            :warning,
            MishkaTranslator.Gettext.dgettext(
              "html_live",
              "چنین مطلبی وجود ندارد یا ممکن است از قبل حذف شده باشد."
            )
          )
          |> push_redirect(to: Routes.live_path(socket, MishkaHtmlWeb.AdminBlogPostsLive))
      end

    {:noreply, socket}
  end

  defp creata_post_state(repo_data) do
    Map.drop(repo_data, [
      :inserted_at,
      :updated_at,
      :__meta__,
      :__struct__,
      :blog_categories,
      :id,
      :blog_likes,
      :blog_tags,
      :blog_tags_mappers,
      :blog_authors
    ])
    |> Map.to_list()
    |> Enum.map(fn {key, value} ->
      %{
        class: "#{search_fields(Atom.to_string(key)).class}",
        type: "#{Atom.to_string(key)}",
        value: value
      }
    end)
    |> Enum.reject(fn x -> x.value == nil end)
  end

  defp upload(socket, upload_id) do
    consume_uploaded_entries(socket, upload_id, fn %{path: path}, entry ->
      dest = Path.join([:code.priv_dir(:mishka_html), "static", "uploads", file_name(entry)])
      File.cp!(path, dest)
      Routes.static_path(socket, "/uploads/#{file_name(entry)}")
    end)
  end

  defp file_name(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    "#{entry.uuid}.#{ext}"
  end

  def basic_menu_list() do
    [
      %{
        type: "title",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "ضروری"),
            class: "badge bg-danger"
          }
        ],
        form: "text",
        class: "col-sm-3",
        title: MishkaTranslator.Gettext.dgettext("html_live", "تیتر"),
        description:
          MishkaTranslator.Gettext.dgettext("html_live", "ساخت تیتر مناسب برای مجموعه مورد نظر")
      },
      %{
        type: "alias_link",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "ضروری"),
            class: "badge bg-danger"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "یکتا"),
            class: "badge bg-success"
          }
        ],
        form: "convert_title_to_link",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "لینک مطلب"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "انتخاب لینک مطلب برای ثبت و نمایش به کاربر. این فیلد یکتا می باشد."
          )
      },
      %{
        type: "category_id",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "پیشنهادی"),
            class: "badge bg-dark"
          }
        ],
        form: "text_search",
        class: "col-sm-3",
        title: MishkaTranslator.Gettext.dgettext("html_live", "مجموعه"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "به واسطه این فیلد می توانید مطلب مورد نظر خود را به یک مجموعه تخصیص بدهید"
          )
      },
      %{
        type: "priority",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "ضروری"),
            class: "badge bg-danger"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بدون اولویت"), :none},
          {MishkaTranslator.Gettext.dgettext("html_live", "پایین"), :low},
          {MishkaTranslator.Gettext.dgettext("html_live", "متوسط"), :medium},
          {MishkaTranslator.Gettext.dgettext("html_live", "بالا"), :high},
          {MishkaTranslator.Gettext.dgettext("html_live", "ویژه"), :featured}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "اولویت"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "انتخاب نوع وضعیت می توانید بر اساس دسترسی های کاربران باشد یا نمایش یا عدم نمایش مجموعه به کاربران."
          )
      },
      %{
        type: "status",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "ضروری"),
            class: "badge bg-danger"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "غیر فعال"), :inactive},
          {MishkaTranslator.Gettext.dgettext("html_live", "فعال"), :active},
          {MishkaTranslator.Gettext.dgettext("html_live", "آرشیو شده"), :archived},
          {MishkaTranslator.Gettext.dgettext("html_live", "حذف با پرچم"), :soft_delete}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "وضعیت"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "انتخاب نوع وضعیت می توانید بر اساس دسترسی های کاربران باشد یا نمایش یا عدم نمایش مجموعه به کاربران."
          )
      },
      %{
        type: "short_description",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "ضروری"),
            class: "badge bg-danger"
          }
        ],
        form: "textarea",
        class: "col-sm-6",
        title: MishkaTranslator.Gettext.dgettext("html_live", "توضیحات کوتاه"),
        description:
          MishkaTranslator.Gettext.dgettext("html_live", "ساخت بلاک توضیحات کوتاه برای مجموعه")
      },
      %{
        type: "main_image",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "ضروری"),
            class: "badge bg-danger"
          }
        ],
        form: "upload",
        class: "col-sm-6",
        title: MishkaTranslator.Gettext.dgettext("html_live", "تصویر اصلی"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "تصویر نمایه مجموعه. این فیلد به صورت تک تصویر می باشد."
          )
      },
      %{
        type: "description",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "ضروری"),
            class: "badge bg-danger"
          }
        ],
        form: "editor",
        class: "col-sm-12",
        title: MishkaTranslator.Gettext.dgettext("html_live", "توضیحات"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "توضیحات اصلی مربوط به مجموعه. این فیلد شامل یک ادیتور نیز می باشد."
          )
      },
      %{
        type: "meta_description",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "پیشنهادی"),
            class: "badge bg-dark"
          }
        ],
        form: "textarea",
        class: "col-sm-6",
        title: MishkaTranslator.Gettext.dgettext("html_live", "توضیحات متا"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "توضیحات خلاصه در مورد محتوا که حدود 200 کاراکتر می باشد."
          )
      },
      %{
        type: "meta_keywords",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "پیشنهادی"),
            class: "badge bg-dark"
          }
        ],
        form: "add_tag",
        class: "col-sm-4",
        title: MishkaTranslator.Gettext.dgettext("html_live", "کلمات کلیدی"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "انتخاب چندین کلمه کلیدی برای ثبت بهتر مجموعه در موتور های جستجو."
          )
      }
    ]
  end

  def more_options_menu_list() do
    [
      %{
        type: "header_image",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "پیشنهادی"),
            class: "badge bg-dark"
          }
        ],
        form: "upload",
        class: "col-sm-6",
        title: MishkaTranslator.Gettext.dgettext("html_live", "تصویر هدر"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "این تصویر در برخی از قالب ها بالای هدر مجموعه نمایش داده می شود"
          )
      },
      %{
        type: "unpublish",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر پیشنهادی"),
            class: "badge bg-warning"
          }
        ],
        form: "text",
        class: "col-sm-3",
        title: MishkaTranslator.Gettext.dgettext("html_live", "تاریخ انقضا"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "شما به واسطه این فیلد می توانید تاریخ انقضا برای یک محتوا را مشخص کنید."
          )
      },
      %{
        type: "custom_title",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر پیشنهادی"),
            class: "badge bg-warning"
          }
        ],
        form: "text",
        class: "col-sm-3",
        title: MishkaTranslator.Gettext.dgettext("html_live", "تیتر سفارشی"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "برای نمایش بهتر در برخی از قالب ها استفاده می گردد"
          )
      },
      %{
        type: "robots",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر پیشنهادی"),
            class: "badge bg-warning"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "هشدار"),
            class: "badge bg-secondary"
          }
        ],
        options: [
          {"IndexFollow", :IndexFollow},
          {"IndexNoFollow", :IndexNoFollow},
          {"NoIndexFollow", :NoIndexFollow},
          {"NoIndexNoFollow", :NoIndexNoFollow}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "وضعیت رباط ها"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            " انتخاب دسترسی رباط ها برای ثبت محتوای مجموعه. لطفا در صورت نداشتن اطلاعات این فیلد را پر نکنید"
          )
      },
      %{
        type: "post_visibility",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "نمایش"), :show},
          {MishkaTranslator.Gettext.dgettext("html_live", "مخفی"), :invisibel},
          {MishkaTranslator.Gettext.dgettext("html_live", "نمایش تست"), :test_show},
          {MishkaTranslator.Gettext.dgettext("html_live", "مخفی تست"), :test_invisibel}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "نمایش مطلب"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "نحوه نمایش مطلب برای مدیریت بهتر دسترسی های کاربران."
          )
      },
      %{
        type: "allow_commenting",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر پیشنهادی"),
            class: "badge bg-warning"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "اجازه ارسال نظر"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "اجازه ارسال نظر از طرف کاربر در پست های تخصیص یافته به این مجموعه"
          )
      },
      %{
        type: "allow_liking",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر پیشنهادی"),
            class: "badge bg-warning"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "اجازه پسند کردن"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "امکان یا اجازه پسند کردن پست های مربوط به این مجموعه"
          )
      },
      %{
        type: "allow_printing",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "اجازه پرینت گرفتن"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "اجازه پرینت گرفتن در صفحه اختصاصی مربوط به پرینت در محتوا"
          )
      },
      %{
        type: "allow_reporting",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "گزارش"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "اجازه گزارش دادن کاربران در محتوا های تخصیص یافته در این مجموعه."
          )
      },
      %{
        type: "allow_social_sharing",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "پیشنهادی"),
            class: "badge bg-dark"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "شبکه های اجتماعی"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "اجازه فعال سازی دکمه اشتراک گذاری در شبکه های اجتماعی"
          )
      },
      %{
        type: "allow_subscription",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "اشتراک"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "اجازه مشترک شدن کاربران در محتوا های تخصیص یافته به این مجموعه"
          )
      },
      %{
        type: "allow_bookmarking",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "بوکمارک"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "اجازه بوک مارک کردن محتوا به وسیله کاربران."
          )
      },
      %{
        type: "show_hits",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "نمایش تعداد بازدید"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "اجازه نمایش تعداد بازدید پست های مربوط به این مجموعه."
          )
      },
      %{
        type: "show_time",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "تاریخ ارسال مطلب"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "نمایش یا عدم نمایش تاریخ ارسال در پست های تخصیص یافته در این مجموعه"
          )
      },
      %{
        type: "show_authors",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "نمایش نویسندگان"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "اجازه نمایش نویسندگان در محتوا های تخصیص یافته به این مجموعه."
          )
      },
      %{
        type: "show_category",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "مجموعه"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "اجازه نمایش مجموعه در محتوا های تخصیص یافته به این مجموعه"
          )
      },
      %{
        type: "show_links",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "لینک ها"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "اجازه نمایش یا عدم نمایش لینک های پیوستی محتوا های تخصیص یافته  به این مجموعه"
          )
      },
      %{
        type: "show_location",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          }
        ],
        options: [
          {MishkaTranslator.Gettext.dgettext("html_live", "بله"), true},
          {MishkaTranslator.Gettext.dgettext("html_live", "خیر"), false}
        ],
        form: "select",
        class: "col-sm-2",
        title: MishkaTranslator.Gettext.dgettext("html_live", "نمایش نقشه"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "اجازه نمایش نقشه در هر محتوا مربوط به این مجموعه."
          )
      },
      %{
        type: "location",
        status: [
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "غیر ضروری"),
            class: "badge bg-info"
          },
          %{
            title: MishkaTranslator.Gettext.dgettext("html_live", "پیشنهادی"),
            class: "badge bg-dark"
          }
        ],
        form: "text",
        class: "col-sm-3",
        title: MishkaTranslator.Gettext.dgettext("html_live", "لوکیشن"),
        description:
          MishkaTranslator.Gettext.dgettext(
            "html_live",
            "مشخص کردن لوکیشن مطلب برای سئو محلی سایت"
          )
      }
    ]
  end

  defp blog_category_post_notification(repo_data, title) do
    description =
      MishkaHtml.get_size_of_words(repo_data.description, 100)
      |> HtmlSanitizeEx.strip_tags()

    notif_info = %{
      section: :blog_post,
      type: :client,
      target: :all,
      section_id: repo_data.id,
      description: description,
      title: title
    }

    Subscription.send_notif_to_subscribed_users(:blog_category, repo_data.category_id, notif_info)
  end
end
