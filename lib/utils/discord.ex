defmodule Discord do
  @moduledoc """
  Discord helpers
  """

  use Nostrum.Consumer

  @doc """
  Check if a channel is public or private

  Returns an atom indicating channel type
  """
  def channel_type(channel_id) do
    with {:ok, chan} <- Nostrum.Api.get_channel(channel_id) do
      if chan.type == 1 do
        :private
      else
        :public
      end
    else
      error -> error
    end
  end

  @doc """
  Check if an id ir a member of a role in a guild

  Returns an atom indicating role membership
  """
  def is_member(user, rid, gid) do
    with {:ok, guild} <- Nostrum.Cache.GuildCache.get(gid) do
      case Map.get(guild.members, user.id) do
        nil ->
          {:error, "User #{user.username} not found in guild #{gid}"}

        m ->
          if Enum.member?(m.roles(), rid) do
            :member
          else
            :not_member
          end
      end
    else
      error -> error
    end
  end

  @doc """
  Helper to generate a string using user ID to a mention to this user

  Returns a string used to mention a user in Discord
  """
  def mention(id) do
    "<@#{id}>"
  end

  @doc """
  Helper to generate a string with a string using channel ID to a mention to this channel

  Returns a string used to mention a channel on Discord
  """
  def channel(id) do
    "<##{id}>"
  end
end
