# frozen_string_literal: true

module DiscourseChat::GuardianExtensions
  def can_moderate_chat?(chatable)
    chatable.class.name == "Topic" ?
      can_perform_action_available_to_group_moderators?(chatable) :
      is_staff?
  end

  def can_chat?(user)
    return false unless user

    allowed_group_ids = DiscourseChat.allowed_group_ids
    return true if allowed_group_ids.include?(Group::AUTO_GROUPS[:everyone])

    (allowed_group_ids & user.group_ids).any?
  end

  def can_create_chat_message?
    !SpamRule::AutoSilence.prevent_posting?(@user)
  end

  def hidden_tag_names
    @hidden_tag_names ||= DiscourseTagging.hidden_tag_names(self)
  end

  def can_create_chat_channel?
    is_staff?
  end

  def can_delete_chat_channel?
    is_staff?
  end

  # Channel status intentionally has no bearing on whether the channel
  # name and description can be edited.
  def can_edit_chat_channel?
    is_staff?
  end

  def can_create_channel_message?(chat_channel)
    return chat_channel.open? || chat_channel.closed? if is_staff?
    chat_channel.open?
  end

  # This is intentionally identical to can_create_channel_message, we
  # may want to have different conditions here in future.
  def can_modify_channel_message?(chat_channel)
    return chat_channel.open? || chat_channel.closed? if is_staff?
    chat_channel.open?
  end

  def can_change_channel_status?(chat_channel, target_status)
    return false if chat_channel.status.to_sym == target_status.to_sym
    return false if !is_staff?

    case target_status
    when :closed
      chat_channel.open?
    when :open
      chat_channel.closed?
    when :archived
      chat_channel.read_only?
    when :read_only
      chat_channel.closed? || chat_channel.open?
    else
      false
    end
  end

  def can_move_chat_to_topic?(chat_channel)
    is_staff? && can_modify_channel_message?(chat_channel)
  end

  def can_rebake_chat_message?(message)
    return false if !can_modify_channel_message?(message.chat_channel)
    is_staff? || @user.has_trust_level?(TrustLevel[4])
  end

  def can_see_chat_channel?(chat_channel)
    return false unless chat_channel.chatable

    if chat_channel.topic_channel?
      !chat_channel.chatable.closed &&
        !chat_channel.chatable.archived &&
        can_see_topic?(chat_channel.chatable)
    elsif chat_channel.direct_message_channel?
      chat_channel.chatable.user_can_access?(@user)
    elsif chat_channel.category_channel?
      can_see_category?(chat_channel.chatable)
    elsif chat_channel.tag_channel?
      !hidden_tag_names.include?(chat_channel.chatable.name)
    else
      true
    end
  end

  def can_flag_chat_messages?
    return false if @user.silenced?

    @user.has_trust_level?(TrustLevel[SiteSetting.min_trust_to_flag_posts])
  end

  def can_flag_in_chat_channel?(chat_channel)
    return false if !can_modify_channel_message?(chat_channel)
    !chat_channel.direct_message_channel?
  end

  def can_flag_chat_message?(chat_message)
    return false if chat_message.user.staff? && !SiteSetting.allow_flagging_staff
    return false if chat_message.user_id == @user.id

    can_flag_chat_messages? && can_flag_in_chat_channel?(chat_message.chat_channel)
  end

  def can_delete_chat?(message, chatable)
    return false if @user.silenced?
    return false if !can_modify_channel_message?(message.chat_channel)

    message.user_id == current_user.id ?
      can_delete_own_chats?(chatable) :
      can_delete_other_chats?(chatable)
  end

  def can_delete_own_chats?(chatable)
    return false if (SiteSetting.max_post_deletions_per_day < 1)
    return true if can_moderate_chat?(chatable)

    if chatable.class.name == "Topic"
      return false if !can_see_topic?(chatable)
      return false if chatable.archived?
      return false if chatable.closed?
    end

    true
  end

  def can_delete_other_chats?(chatable)
    if chatable.class.name == "Topic"
      return false if chatable.archived?
      return false if chatable.closed?
    end
    return true if can_moderate_chat?(chatable)

    false
  end

  def can_restore_chat?(message, chatable)
    return false if !can_modify_channel_message?(message.chat_channel)

    message.user_id == current_user.id ?
      can_restore_own_chats?(chatable) :
      can_delete_other_chats?(chatable)
  end

  def can_restore_own_chats?(chatable)
    if chatable.class.name == "Topic"
      return false if !can_see_topic?(chatable)
      return false if chatable.archived? || chatable.closed?
    else
      return false if !can_see_category?(chatable)
    end

    true
  end

  def can_restore_other_chats?(chatable)
    if chatable.class.name == "Topic"
      return false if chatable.archived?
    end

    can_moderate_chat?(chatable)
  end

  def can_edit_chat?(message)
    message.user_id == @user.id && !@user.silenced?
  end

  def can_react?
    can_create_chat_message?
  end
end
