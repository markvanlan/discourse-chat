import showModal from "discourse/lib/show-modal";
import {
  acceptance,
  exists,
  query,
  queryAll,
  updateCurrentUser,
  visible,
} from "discourse/tests/helpers/qunit-helpers";

import {
  click,
  currentURL,
  fillIn,
  settled,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import {
  chatChannels,
  chatView,
} from "discourse/plugins/discourse-chat/chat-fixtures";
import ChatChannel from "discourse/plugins/discourse-chat/discourse/models/chat-channel";
import { test } from "qunit";
import { isLegacyEmber } from "discourse-common/config/environment";

if (!isLegacyEmber()) {
  acceptance("Discourse Chat - Keyboard shortcuts", function (needs) {
    needs.user({
      admin: false,
      moderator: false,
      username: "eviltrout",
      id: 1,
      can_chat: true,
      has_chat_enabled: true,
    });
    needs.pretender((server, helper) => {
      server.get("/chat/chat_channels.json", () =>
        helper.response(chatChannels)
      );
      server.get("/chat/:chatChannelId/messages.json", () =>
        helper.response(chatView)
      );
      server.post("/uploads/lookup-urls", () => {
        return helper.response([]);
      });
      server.post("/chat/drafts", () => {
        return helper.response([]);
      });

      server.get("/chat/chat_channels/search", () => {
        return helper.response({
          public_channels: [ChatChannel.create({ id: 3, name: "seventeen" })],
          direct_message_channels: [
            ChatChannel.create({
              id: 4,
              users: [{ id: 10, username: "someone" }],
            }),
          ],
          users: [
            { id: 11, username: "smoothies" },
            { id: 12, username: "server" },
          ],
        });
      });
    });

    needs.settings({
      chat_enabled: true,
    });

    needs.hooks.beforeEach(function () {
      Object.defineProperty(this, "chatService", {
        get: () => this.container.lookup("service:chat"),
      });
    });

    test("channel selector opens channel in float with chat not isolated", async function (assert) {
      updateCurrentUser({ chat_isolated: false });
      await visit("/latest");

      await showModal("chat-channel-selector-modal");
      await settled();
      assert.ok(exists("#chat-channel-selector-modal-inner"));

      // All 6 channels should show because the input is blank
      assert.equal(
        queryAll(
          "#chat-channel-selector-modal-inner .chat-channel-selection-row"
        ).length,
        6
      );

      // Freaking keyup event isn't triggered by fillIn...
      // Next line manually keyup's "r" to make the keyup event run.
      // fillIn is needed for `this.filter` but triggerKeyEvent is needed to fire the JS event.
      await fillIn("#chat-channel-selector-input", "s");
      await triggerKeyEvent("#chat-channel-selector-input", "keyup", 83);
      await settled();
      // Only 4 channels match this filter now!
      assert.equal(
        queryAll(
          "#chat-channel-selector-modal-inner .chat-channel-selection-row"
        ).length,
        4
      );

      await triggerKeyEvent(document.body, "keyup", 13); // Enter key
      assert.ok(exists(".topic-chat-container.visible"));
      assert.notOk(exists("#chat-channel-selector-modal-inner"));
      assert.equal(currentURL(), "/latest");
    });

    test("channel selector opens full-page when chat is isolated", async function (assert) {
      updateCurrentUser({ chat_isolated: true });
      await visit("/latest");
      await showModal("chat-channel-selector-modal");
      await settled();
      await click(
        "#chat-channel-selector-modal-inner .chat-channel-selection-row.channel-row[data-id='75']"
      );
      assert.notOk(exists("#chat-channel-selector-modal-inner"));
      assert.equal(currentURL(), "/chat/channel/75/@hawk");
    });

    test("the current chat channel does not show in the channel selector list", async function (assert) {
      await visit("/chat/channel/75/@hawk");
      await showModal("chat-channel-selector-modal");
      await settled();

      // Only 5 channels now instead of 6.
      assert.equal(
        queryAll(
          "#chat-channel-selector-modal-inner .chat-channel-selection-row"
        ).length,
        5
      );
      assert.notOk(
        exists(
          "#chat-channel-selector-modal-inner .chat-channel-selection-row.chat-channel-75"
        )
      );
    });

    test("switching channel with alt+arrow keys in full page chat", async function (assert) {
      await visit("/chat/channel/75/@hawk");
      await triggerKeyEvent(document.body, "keydown", 40, { altKey: true }); // Down key
      assert.equal(currentURL(), "/chat/channel/76/@eviltrout");
      await triggerKeyEvent(document.body, "keydown", 40, { altKey: true }); // Down key
      assert.equal(currentURL(), "/chat/channel/9/Site");
      await triggerKeyEvent(document.body, "keydown", 40, { altKey: true }); // Down key
      assert.equal(currentURL(), "/chat/channel/7/Uncategorized");
      await triggerKeyEvent(document.body, "keydown", 38, { altKey: true }); // Up key
      assert.equal(currentURL(), "/chat/channel/9/Site");
      await triggerKeyEvent(document.body, "keydown", 38, { altKey: true }); // Up key
      assert.equal(currentURL(), "/chat/channel/76/@eviltrout");
      await triggerKeyEvent(document.body, "keydown", 38, { altKey: true }); // Up key
      assert.equal(currentURL(), "/chat/channel/75/@hawk");
    });

    test("switching channel with alt+arrow keys in float", async function (assert) {
      await visit("/latest");
      this.chatService.set("sidebarActive", false);
      await click(".header-dropdown-toggle.open-chat");
      await settled();
      assert.ok(visible(".topic-chat-float-container"), "chat float is open");
      assert.ok(query(".topic-chat-container").classList.contains("channel-4"));

      await triggerKeyEvent(document.body, "keydown", 40, { altKey: true }); // Down key
      assert.ok(
        query(".topic-chat-container").classList.contains("channel-75")
      );

      await triggerKeyEvent(document.body, "keydown", 40, { altKey: true }); // Down key
      assert.ok(
        query(".topic-chat-container").classList.contains("channel-76")
      );

      await triggerKeyEvent(document.body, "keydown", 40, { altKey: true }); // Down key
      assert.ok(query(".topic-chat-container").classList.contains("channel-9"));

      await triggerKeyEvent(document.body, "keydown", 40, { altKey: true }); // Down key
      assert.ok(query(".topic-chat-container").classList.contains("channel-7"));

      await triggerKeyEvent(document.body, "keydown", 40, { altKey: true }); // Down key
      assert.ok(
        query(".topic-chat-container").classList.contains("channel-11")
      );

      await triggerKeyEvent(document.body, "keydown", 40, { altKey: true }); // Down key
      assert.ok(query(".topic-chat-container").classList.contains("channel-4"));

      await triggerKeyEvent(document.body, "keydown", 38, { altKey: true }); // Up key
      assert.ok(
        query(".topic-chat-container").classList.contains("channel-11")
      );
    });

    test("simple composer formatting shortcuts", async function (assert) {
      await visit("/latest");
      this.chatService.set("sidebarActive", false);
      await click(".header-dropdown-toggle.open-chat");
      await settled();
      const composerInput = query(".chat-composer-input");
      await fillIn(composerInput, "test text");
      await focus(composerInput);
      composerInput.selectionStart = 0;
      composerInput.selectionEnd = 9;
      await triggerKeyEvent(composerInput, "keydown", 66, { ctrlKey: true }); // ctrl+b
      await settled();
      assert.strictEqual(
        composerInput.value,
        "**test text**",
        "selection should get the bold markdown"
      );
      await fillIn(composerInput, "test text");
      await focus(composerInput);
      composerInput.selectionStart = 0;
      composerInput.selectionEnd = 9;
      await triggerKeyEvent(composerInput, "keydown", 73, { ctrlKey: true }); // ctrl+i
      await settled();
      assert.strictEqual(
        composerInput.value,
        "_test text_",
        "selection should get the italic markdown"
      );
      await fillIn(composerInput, "test text");
      await focus(composerInput);
      composerInput.selectionStart = 0;
      composerInput.selectionEnd = 9;
      await triggerKeyEvent(composerInput, "keydown", 69, { ctrlKey: true }); // ctrl+e
      await settled();
      assert.strictEqual(
        composerInput.value,
        "`test text`",
        "selection should get the code markdown"
      );
    });

    test("insert link shortcut", async function (assert) {
      await visit("/latest");
      this.chatService.set("sidebarActive", false);
      await click(".header-dropdown-toggle.open-chat");
      await settled();
      const composerInput = query(".chat-composer-input");
      await fillIn(composerInput, "This is a link to ");
      await focus(composerInput);
      await triggerKeyEvent(composerInput, "keydown", 76, { ctrlKey: true }); // ctrl+l

      assert.ok(exists(".insert-link.modal-body"), "hyperlink modal visible");

      await fillIn(".modal-body .link-url", "google.com");
      await fillIn(".modal-body .link-text", "Google");
      await click(".modal-footer button.btn-primary");

      assert.strictEqual(
        composerInput.value,
        "This is a link to [Google](https://google.com)",
        "adds link with url and text, prepends 'https://'"
      );

      assert.ok(
        !exists(".insert-link.modal-body"),
        "modal dismissed after submitting link"
      );
    });
  });
}
