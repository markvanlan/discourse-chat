import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";
import { later } from "@ember/runloop";
import { popupAjaxError } from "discourse/lib/ajax-error";

const NOTIFICATION_LEVELS = [
  { name: I18n.t("chat.notification_levels.never"), value: "never" },
  { name: I18n.t("chat.notification_levels.mention"), value: "mention" },
  { name: I18n.t("chat.notification_levels.always"), value: "always" },
];

const MUTED_OPTIONS = [
  { name: I18n.t("chat.settings.muted_on"), value: true },
  { name: I18n.t("chat.settings.muted_off"), value: false },
];

export default Component.extend({
  channel: null,
  loading: false,
  showSaveSuccess: false,
  notificationLevels: NOTIFICATION_LEVELS,
  mutedOptions: MUTED_OPTIONS,
  chat: service(),
  router: service(),

  didInsertElement() {
    this._super(...arguments);
  },

  @discourseComputed("channel.chatable_type")
  chatChannelClass(channelType) {
    return `${channelType.toLowerCase()}-chat-channel`;
  },

  @action
  startEditingName() {
    this.setProperties({
      newName: this.channel.title,
      editingName: true,
    });
    return false;
  },

  @discourseComputed("newName")
  saveNameEditDisabled(name) {
    return !name || name.trim() === "";
  },

  @action
  cancelNameChange() {
    this.set("editingName", false);
  },

  @action
  saveNameChange() {
    return ajax(`/chat/chat_channels/${this.channel.id}`, {
      method: "POST",
      data: {
        name: this.newName.trim(),
      },
    })
      .then((response) => {
        this.set("editingName", false);
        this.channel.setProperties({
          title: response.chat_channel.title,
          description: response.chat_channel.description,
        });
      })
      .catch(popupAjaxError);
  },

  @action
  follow() {
    this.set("loading", true);
    return ajax(`/chat/chat_channels/${this.channel.id}/follow`, {
      method: "POST",
    })
      .then((membership) => {
        this.channel.setProperties({
          following: true,
          muted: membership.muted,
          desktop_notification_level: membership.desktop_notification_level,
          mobile_notification_level: membership.mobile_notification_level,
        });
        this.chat.startTrackingChannel(this.channel);
        this.set("loading", false);
      })
      .catch(popupAjaxError);
  },

  @action
  unfollow() {
    this.set("loading", true);
    return ajax(`/chat/chat_channels/${this.channel.id}/unfollow`, {
      method: "POST",
    })
      .then(() => {
        this.channel.setProperties({
          expanded: false,
          following: false,
        });
        this.chat.stopTrackingChannel(this.channel);
        this.set("loading", false);
      })
      .catch(popupAjaxError);
  },

  @action
  toggleExpanded() {
    this.channel.set("expanded", !this.channel.expanded);
    const expandBtn = this.element.querySelector(
      ".chat-channel-expand-settings"
    );
    if (expandBtn) {
      expandBtn.blur(); // Button isn't losing focus naturally.
    }
    return false;
  },

  @action
  save() {
    this.set("loading", true);
    return ajax(
      `/chat/chat_channels/${this.channel.id}/notification_settings`,
      {
        method: "POST",
        data: {
          muted: this.channel.muted,
          desktop_notification_level: this.channel.desktop_notification_level,
          mobile_notification_level: this.channel.mobile_notification_level,
        },
      }
    )
      .then(() => {
        this.setProperties({
          loading: false,
          showSaveSuccess: true,
        });
        later(() => {
          if (!this.isDestroying && !this.isDestroyed) {
            this.set("showSaveSuccess", false);
          }
        }, 2000);
      })
      .catch(popupAjaxError);
  },

  @action
  previewChannel() {
    this.router.transitionTo(
      "chat.channel",
      this.channel.id,
      this.channel.title
    );
  },
});
