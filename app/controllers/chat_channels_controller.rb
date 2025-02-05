# frozen_string_literal: true

class DiscourseChat::ChatChannelsController < DiscourseChat::ChatBaseController
  def index
    structured = DiscourseChat::ChatChannelFetcher.structured(guardian)
    render_serialized(structured, ChatChannelIndexSerializer, root: false)
  end

  def all
    channels = DiscourseChat::ChatChannelFetcher.secured_public_channels(
      guardian,
      UserChatChannelMembership.where(user: current_user),
      scope_with_membership: false
    )

    render_serialized(channels, ChatChannelSettingsSerializer)
  end

  def show
    set_channel_and_chatable
    render_serialized(@chat_channel, ChatChannelSerializer)
  end

  def follow
    params.require(:chat_channel_id)

    membership = UserChatChannelMembership
      .includes(:chat_channel)
      .find_or_create_by(
        user_id: current_user.id,
        chat_channel_id: params[:chat_channel_id]
      )

    if membership.following
      return render_serialized(membership, UserChatChannelMembershipSerializer, root: false)
    end

    # Need to set following and `save` rather than `update` because it's possible this is a new
    # record, since the membership is fetched with `find_or_create_by`.
    membership.following = true
    if (membership.save)
      membership.chat_channel.update(user_count: (membership.chat_channel.user_count || 0) + 1)
      render_serialized(membership, UserChatChannelMembershipSerializer, root: false)
    else
      render_json_error(membership)
    end
  end

  def unfollow
    params.require(:chat_channel_id)

    membership = UserChatChannelMembership
      .includes(:chat_channel)
      .find_by(
        user_id: current_user.id,
        chat_channel_id: params[:chat_channel_id]
      )
    if (membership && membership.update(following: false))
      new_user_count = [(membership.chat_channel.user_count || 0) - 1, 0].max
      membership.chat_channel.update(user_count: new_user_count)
      render json: success_json
    else
      render_json_error(membership)
    end
  end

  def notification_settings
    params.require([
      :chat_channel_id,
      :muted,
      :desktop_notification_level,
      :mobile_notification_level
    ])

    membership = UserChatChannelMembership.find_by(
      user_id: current_user.id,
      chat_channel_id: params[:chat_channel_id]
    )
    raise Discourse::NotFound unless membership

    if membership.update(
      muted: params[:muted],
      desktop_notification_level: params[:desktop_notification_level],
      mobile_notification_level: params[:mobile_notification_level]
    )
      render json: success_json
    else
      render_json_error(membership)
    end
  end

  def create
    params.require([:type, :id, :name])
    guardian.ensure_can_create_chat_channel!
    raise Discourse::InvalidParameters unless ["topic", "category"].include?(params[:type].downcase)
    raise Discourse::InvalidParameters.new(:name) if params[:name].length > SiteSetting.max_topic_title_length

    creating_topic_channel = params[:type].downcase === "topic"
    chatable_type = creating_topic_channel ? "Topic" : "Category"
    existing_args = {
      chatable_type: chatable_type,
      chatable_id: params[:id]
    }
    existing_args[:name] = params[:name] unless creating_topic_channel
    exists = ChatChannel.exists?(existing_args)

    if exists
      translation_key = creating_topic_channel ? "channel_exists_for_topic" : "channel_exists_for_category"
      raise Discourse::InvalidParameters.new(I18n.t("chat.errors.#{translation_key}"))
    end

    chatable = chatable_type.constantize.find_by(id: params[:id])
    raise Discourse::NotFound unless chatable

    chat_channel = ChatChannel.create!(chatable: chatable, name: params[:name], description: params[:description], user_count: 1)
    chat_channel.user_chat_channel_memberships.create!(user: current_user, following: true)

    if creating_topic_channel
      chatable.custom_fields[DiscourseChat::HAS_CHAT_ENABLED] = true
      chatable.save
    end
    render_serialized(chat_channel, ChatChannelSerializer)
  end

  def edit
    guardian.ensure_can_edit_chat_channel!
    if (params[:name]&.length || 0) > SiteSetting.max_topic_title_length
      raise Discourse::InvalidParameters.new(:name)
    end

    chat_channel = ChatChannel.find_by(id: params[:chat_channel_id])
    raise Discourse::NotFound unless chat_channel

    chat_channel.name = params[:name] if params[:name]
    chat_channel.description = params[:description] if params[:description]
    chat_channel.save!

    ChatPublisher.publish_channel_edit(chat_channel)
    render_serialized(chat_channel, ChatChannelSerializer)
  end

  def search
    params.require(:filter)
    filter = params[:filter]&.downcase
    memberships = UserChatChannelMembership.where(user: current_user)
    public_channels = DiscourseChat::ChatChannelFetcher.public_channels_with_filter(
      guardian,
      memberships,
      filter
    )

    users = User.joins(:user_option)
    unless DiscourseChat.allowed_group_ids.include?(Group::AUTO_GROUPS[:everyone])
      users = users.joins(:groups).where(groups: { id: DiscourseChat.allowed_group_ids })
    end

    users = users.where(user_option: { chat_enabled: true })
    like_filter = "#{filter}%"
    if SiteSetting.enable_names
      users = users.where("LOWER(users.name) LIKE ? OR LOWER(users.username) LIKE ?", like_filter, like_filter)
    else
      users = users.where("LOWER(users.username) LIKE ?", like_filter)
    end

    users = users.limit(25).uniq
    # Need to filter out current user for chat channel query
    users.reject! { |user| user.id === current_user.id }

    direct_message_channels = users.count > 0 ?
      ChatChannel
        .includes(chatable: :users)
        .joins(direct_message_channel: :direct_message_users)
        .group(1)
        .having("ARRAY[?] <@ ARRAY_AGG(user_id) AND ARRAY[?] && ARRAY_AGG(user_id)", [current_user.id], users.map(&:id)) : []

    user_ids_with_channel = []
    direct_message_channels.each do |dm_channel|
      user_ids = dm_channel.chatable.users.map(&:id)
      if user_ids.count < 3
        user_ids_with_channel.concat(user_ids)
      end
    end

    users_without_channel = users.filter { |u| !user_ids_with_channel.include?(u.id) }

    if current_user.username.downcase.start_with?(filter)
      # We filtered out the current user for the query earlier, but check to see
      # if they should be included, and add.
      users_without_channel << current_user
    end

    render_serialized({
      public_channels: public_channels,
      direct_message_channels: direct_message_channels,
      users: users_without_channel
    }, ChatChannelSearchSerializer, root: false)
  end

  def archive
    params.require(:chat_channel_id)
    params.require(:type)

    if params[:type] == "newTopic" ? params[:title].blank? : params[:topic_id].blank?
      raise Discourse::InvalidParameters
    end

    chat_channel = ChatChannel.find_by(id: params[:chat_channel_id])
    raise Discourse::NotFound if chat_channel.blank?

    if !guardian.can_change_channel_status?(chat_channel, :read_only)
      raise Discourse::InvalidAccess.new(I18n.t("chat.errors.channel_cannot_be_archived"))
    end

    DiscourseChat::ChatChannelArchiveService.begin_archive_process(
      chat_channel: chat_channel,
      acting_user: current_user,
      topic_params: {
        topic_id: params[:topic_id],
        topic_title: params[:title],
        category_id: params[:category_id],
        tags: params[:tags]
      }
    )

    render json: success_json
  end

  def retry_archive
    params.require(:chat_channel_id)

    chat_channel = ChatChannel.find_by(id: params[:chat_channel_id])
    raise Discourse::NotFound if chat_channel.blank?
    guardian.ensure_can_change_channel_status!(chat_channel, :archived)

    archive = chat_channel.chat_channel_archive
    raise Discourse::NotFound if archive.blank?
    raise Discourse::InvalidAccess if !archive.failed?

    DiscourseChat::ChatChannelArchiveService.retry_archive_process(chat_channel: chat_channel)

    render json: success_json
  end

  def change_status
    params.require(:chat_channel_id)
    params.require(:status)

    # we only want to use this endpoint for open/closed status changes,
    # the others are more "special" and are handled by the archive endpoint
    if !ChatChannel.statuses.keys.include?(params[:status]) ||
        params[:status] == "read_only" ||
        params[:status] == "archive"
      raise Discourse::InvalidParameters
    end

    chat_channel = ChatChannel.find_by(id: params[:chat_channel_id])
    raise Discourse::NotFound if chat_channel.blank?

    guardian.ensure_can_change_channel_status!(chat_channel, params[:status].to_sym)
    chat_channel.public_send("#{params[:status]}!", current_user)

    render json: success_json
  end

  def destroy
    params.require(:chat_channel_id)
    params.require(:channel_name_confirmation)

    chat_channel = ChatChannel.find_by(id: params[:chat_channel_id])
    raise Discourse::NotFound if chat_channel.blank?

    guardian.ensure_can_delete_chat_channel!

    if chat_channel.name.downcase != params[:channel_name_confirmation].downcase
      raise Discourse::InvalidParameters.new(:channel_name_confirmation)
    end

    begin
      ChatChannel.transaction do
        chat_channel.trash!(current_user)
        StaffActionLogger.new(current_user).log_custom(
          "chat_channel_delete",
          {
            chat_channel_id: chat_channel.id,
            chat_channel_name: chat_channel.name
          }
        )
      end
    rescue ActiveRecord::Rollback
      return render_json_error(I18n.t("chat.errors.delete_channel_failed"))
    end

    Jobs.enqueue(:chat_channel_delete, { chat_channel_id: chat_channel.id })
    render json: success_json
  end

  private

  def render_channel_for_chatable(channel)
    if channel
      guardian.ensure_can_see_chat_channel!(channel)
      render_serialized(channel, ChatChannelSerializer)
    else
      render json: { chat_channel: nil }
    end
  end
end
