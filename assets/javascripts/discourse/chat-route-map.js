export default function () {
  this.route("chat", { path: "/chat" }, function () {
    this.route("channel", { path: "/channel/:channelId/:channelTitle" });
    this.route("browse", { path: "/browse" });
    this.route("message", { path: "/message/:messageId" });
    this.route("channelByName", { path: "/chat_channels/:channelName" });
  });
}
