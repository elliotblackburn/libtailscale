defmodule Tailscale.Listener do
  @moduledoc """
  A Tailscale listener for accepting connections.
  """

  defstruct [:reference, :server]

  @type t :: %__MODULE__{
    reference: reference(),
    server: pid()
  }

  @doc """
  Accept a connection from the listener.
  
  Returns `{:ok, socket}` where socket is a file descriptor that can be used with
  `:gen_tcp` and other Erlang socket functions, or `{:error, reason}`.
  """
  @spec accept(t()) :: {:ok, :inet.socket()} | {:error, any()}
  def accept(%__MODULE__{reference: ref}) do
    case Tailscale.NIF.tailscale_accept(ref) do
      {:ok, fd} ->
        # Convert the file descriptor into a socket that can be used with gen_tcp
        case :erlang.open_port({:fd, fd, fd}, [:binary]) do
          port when is_port(port) ->
            {:ok, port}
          _ ->
            {:error, :failed_to_open_port}
        end
      error ->
        error
    end
  end

  @doc """
  Close the listener.
  """
  @spec close(t()) :: :ok | {:error, any()}
  def close(%__MODULE__{reference: ref}) do
    case :erlang.port_close(ref) do
      true -> :ok
      false -> {:error, :failed_to_close}
    end
  end

  @doc """
  Get the remote address of a connection.
  """
  @spec get_remote_addr(t(), :inet.socket()) :: {:ok, String.t()} | {:error, any()}
  def get_remote_addr(%__MODULE__{reference: ref}, conn) do
    fd = case conn do
      port when is_port(port) ->
        {:ok, fd} = :erlang.port_info(port, :fd)
        fd
      fd when is_integer(fd) ->
        fd
    end

    Tailscale.NIF.tailscale_getremoteaddr(ref, fd, 1024)
  end
end