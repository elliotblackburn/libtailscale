defmodule Tailscale.LocalAPI do
  @moduledoc """
  Client for the Tailscale Local API.
  """

  defmodule Client do
    @moduledoc """
    HTTP client for the Tailscale Local API.
    """

    defstruct [:address, :credential]

    @type t :: %__MODULE__{
      address: String.t(),
      credential: String.t()
    }

    @doc """
    Create a new LocalAPI client.
    """
    @spec new(String.t(), String.t()) :: t()
    def new(address, credential) do
      %__MODULE__{
        address: address,
        credential: credential
      }
    end
  end

  @doc """
  Get the status of the local tailscale node.
  """
  @spec status(Client.t()) :: {:ok, map()} | {:error, any()}
  def status(%Client{} = client) do
    request(client, :get, "/localapi/v0/status")
  end

  @doc """
  Get the status of peers on the tailnet.
  """
  @spec peers(Client.t()) :: {:ok, map()} | {:error, any()}
  def peers(%Client{} = client) do
    with {:ok, status} <- status(client) do
      {:ok, get_in(status, ["Peer"])}
    end
  end

  # Helper functions for making HTTP requests to the Local API
  defp request(%Client{} = client, method, path, body \\ nil) do
    url = client.address <> path
    headers = [
      {"Sec-Tailscale", "localapi"},
      {"Authorization", "Basic " <> Base.encode64(":" <> client.credential)}
    ]

    req_options = [
      method: method,
      url: url,
      headers: headers
    ]

    # Add body to options if provided
    req_options = if body, do: Keyword.put(req_options, :json, body), else: req_options

    case Req.request(req_options) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "HTTP error: #{status} #{inspect(body)}"}
      {:error, %Req.HTTPError{} = error} ->
        {:error, error}
      {:error, reason} ->
        {:error, reason}
    end
  end
end