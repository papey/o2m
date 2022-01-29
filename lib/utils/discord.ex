defmodule Discord do
  @moduledoc """
  Discord helpers
  """

  use Nostrum.Consumer

  @doc """
  Check if a channel is private

  Returns an :ok tuple
  """
  def is_chan_private(channel_id) do
    with {:ok, chan} <- Nostrum.Api.get_channel(channel_id) do
      if chan.type == 1,
        do: {:ok, chan},
        else: {:error, "Channel #{channel(chan.id)} is not private"}
    end
  end

  @doc """
  Check if a channel is public

  Returns an :ok tuple
  """
  def is_chan_public(channel_id) do
    with {:ok, chan} <- Nostrum.Api.get_channel(channel_id) do
      if chan.type != 1, do: {:ok, chan}, else: {:error, "Channel #{channel(chan.id)} is private"}
    end
  end

  @doc """
  Check if an id is a member of a role in a guild, use to ensure permissions on commands

  Returns an atom indicating role membership
  """
  def member_has_persmission(user, rid, gid) do
    with {:ok, guild} <- Nostrum.Cache.GuildCache.get(gid) do
      case Map.get(guild.members, user.id) do
        nil ->
          {:error, "User #{user.username} not found in guild #{gid}"}

        m ->
          if Enum.member?(m.roles(), rid) do
            {:ok}
          else
            {:error, "User #{mention(user.id)} do not have the required permission"}
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
