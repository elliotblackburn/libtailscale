defmodule Tailscale.Error do
  @moduledoc """
  Defines errors that can occur when using Tailscale.
  """

  defexception [:message, :reason, :code]

  @type t :: %__MODULE__{
    message: String.t(),
    reason: atom(),
    code: integer()
  }

  @doc """
  Creates a new Tailscale error.
  """
  def new(message, reason \\ :unknown, code \\ -1) do
    %__MODULE__{message: message, reason: reason, code: code}
  end

  @doc """
  Formats the error message.
  """
  def message(%__MODULE__{message: message, code: code}) when code != -1 do
    "#{message} (code: #{code})"
  end

  def message(%__MODULE__{message: message}) do
    message
  end
end