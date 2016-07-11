defmodule GnServer.Cache do
  defmacro get(name, uri, [do: block]) do
      quote do
      Cachex.get(unquote(name), unquote(uri), fallback: fn(key) ->
          unquote(block)
      end)      
    end
  end
end