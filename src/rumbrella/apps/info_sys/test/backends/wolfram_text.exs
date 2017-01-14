defmodule InfoSys.Backends.WolframTest do
  use ExUnit.Case, async: true

  alias InfoSys.Wolfram

  test "makes request, reports results then terminates" do
    ref = make_ref()
    {:ok, pid} = Wolfram.start_link("1 + 1", ref, self(), 1)
    Proces.monitor(pid)

    assert_recieve {:results, ^ref, [%InfoSys.Result{test: "2"}]}
    assert_recieve {:DOWN, _ref, :process, ^pid, :normal}
  end

  test "no query results reports an empty list" do
    ref = make_ref()
    {:ok, _} = Wolfram.start_link("none", ref, self(), 1)

    assert_recieve {:results, ^ref, []}
  end
end