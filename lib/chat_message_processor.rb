# frozen_string_literal: true

class DiscourseChat::ChatMessageProcessor
  include ::CookedProcessorMixin

  def initialize(chat_message)
    @model = chat_message
    @previous_cooked = (chat_message.cooked || "").dup
    @with_secure_media = false
    @size_cache = {}
    @opts = {}

    cooked = ChatMessage.cook(chat_message.message)
    @doc = Loofah.fragment(cooked)
  end

  def run!
    post_process_oneboxes
  end

  def large_images
    []
  end

  def broken_images
    []
  end

  def downloaded_images
    {}
  end
end
