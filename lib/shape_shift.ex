defmodule ShapeShift do
  alias Exshape.Shp

  @moduledoc """
  Converts Exshape structs to Geo structs.

  This allows for reading Shapefiles and immediately using
  them with Geo, and in turn, Ecto. In addition, the data
  structures have been reformatted for ease of use.
  """

  @doc """
  Convert given Exshape shape to its matching Geo Struct.

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

  @doc """
  Open a zip-compressed directory containing Shapefile, Proj4, and
  DBF files, and convert each shape into a map containing geometry and
  attribute information.

  ## Examples
    iex> [{name, proj, stream}] = ShapeShift.from_zip("test/fixtures/hoods.zip")
    [{
      "neighborhoods_orleans",
      "GEOGCS[\"GCS_North_American_1983\",DATUM[\"D_North_American_1983\",SPHEROID[\"GRS_1980\",6378137.0,298.257222101]],PRIMEM[\"Greenwich\",0.0],UNIT[\"Degree\",0.0174532925199433]]",
      #Function<24.4896 in Stream.transform/3>
    }]
    iex> Enum.to_list(stream) |> List.last()
    %{attributes: %{"DIST" => "Algiers", "DIST_NUM" => "12", "HS_DIS" => "",
    "LBL_SHRT" => "Whitney", "NBHD" => "Whitney", "NBHD_NUM" => 2,
    "POLICE_DIS" => "0"},
  geometry: %Geo.Polygon{coordinates: [[{-90.045872, 29.951904},
     {-90.045772, 29.953104}, {-90.045672, 29.954203999999997}, {-90.244896, ...}, {...}, ...]]
  """
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
