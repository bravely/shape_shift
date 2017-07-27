defmodule ShapeShift do
  alias Exshape.Shp

  @moduledoc """
  Converts Exshape structs to Geo structs.

  This allows for reading Shapefiles and immediately using
  them with Geo, and in turn, Ecto.
  """

  def shape_stream do
    [{_name, _proj, stream}] = Exshape.from_zip("/Users/pepyri/Downloads/tl_2016_16_sldl.zip")
    stream
  end

  @doc """
  Convert given Exshape shape to Geo Struct.

  For shapes that contain other shapes or complex sets of
  coordinates, uses recursion to simplify processing.

  ## Examples
      iex> ShapeShift.to_geo(%Exshape.Shp.Point{x: -113, y: 60})
      %Geo.Point{coordinates: {-113, 60}, srid: nil}
  """
  def to_geo(%Shp.Point{x: x, y: y}) do
    %Geo.Point{coordinates: {x, y}, srid: nil}
  end
  def to_geo(%Shp.PointM{x: x, y: y, m: m}) do
    %Geo.PointM{coordinates: {x, y, m}, srid: nil}
  end
  def to_geo(%Shp.Polygon{points: shapes}) do
    %Geo.Polygon{coordinates: to_geo(shapes), srid: nil}
  end
  def to_geo(%Shp.Multipoint{points: shapes}) do
    %Geo.MultiPoint{coordinates: to_geo(shapes), srid: nil}
  end

  def to_geo(shape, opts \\ [])
  def to_geo(%Shp.Point{x: x, y: y}, inner: true) do
    {x, y}
  end
  def to_geo(%Shp.PointM{x: x, y: y, m: m}, inner: true) do
    {x, y, m}
  end
  def to_geo(shapes, _opts) when is_list(shapes) do
    Enum.map(shapes, &to_geo(&1, inner: true))
  end

  # Perhaps include BBox/Header info with shapes?
  def from_zip(path) do
    path
    |> Exshape.from_zip()
    |> Enum.map(fn({name, proj, stream}) ->
      {name, proj, convert_stream(stream)}
    end)
  end

  defp convert_stream(stream) do
    stream
    |> Stream.with_index()
    |> Stream.transform(%{}, fn(i, acc) ->
      case i do
        {headers, 0} ->
          {[], convert_headers(headers)}
        {{shapes, features}, _} ->
          {
            [%{
              geometry: to_geo(shapes),
              attributes: map_column_features(features, acc.columns)
            }],
            acc
          }
      end
    end)
  end

  defp convert_headers(headers) do
    headers
    |> Tuple.to_list()
    |> Enum.map(&Map.from_struct/1)
    |> Enum.reduce(%{}, fn(i, acc) ->
      Map.merge(acc, i)
    end)
  end

  defp map_column_features(features, columns) do
    columns
    |> Enum.map(&Map.get(&1, :name))
    |> Enum.zip(features)
    |> Enum.into(%{})
  end
end
