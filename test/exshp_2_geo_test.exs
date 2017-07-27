defmodule ShapeShiftTest do
  use ExUnit.Case, async: true
  alias Exshape.Shp

  doctest ShapeShift

  describe "to_geo" do
    test "converts an Exshape Point to a Geo.Point" do
      assert(
        ShapeShift.to_geo(%Shp.Point{x: 1, y: 99}) == %Geo.Point{coordinates: {1, 99}, srid: nil}
      )
    end

    test "converts an Exshape PointM to a Geo.PointM" do
      assert(
        ShapeShift.to_geo(%Shp.PointM{x: 4, y: 2, m: 24}) == %Geo.PointM{coordinates: {4, 2, 24}, srid: nil}
      )
    end

    test "converts an Exshape Multipoint to a Geo.MultiPoint" do
      shifted =
        %Shp.Multipoint{points: [
          %Shp.Point{x: 1, y: 2},
          %Shp.Point{x: 3, y: 4},
          %Shp.Point{x: 5, y: 6}
        ], bbox: nil}
        |> ShapeShift.to_geo()

      geo_multipoint =
        %Geo.MultiPoint{coordinates: [{1, 2}, {3, 4}, {5, 6}], srid: nil}
      assert shifted == geo_multipoint
    end

    test "recursively converts Polygons" do
      exshp_polygon =
        %Shp.Polygon{points: [[
          %Shp.Point{x: 1, y: 2},
          %Shp.Point{x: 3, y: 4},
          %Shp.Point{x: 5, y: 6}
        ]]}

      geo_polygon =
        %Geo.Polygon{coordinates: [[{1, 2}, {3, 4}, {5, 6}]], srid: nil}
      assert(
        ShapeShift.to_geo(exshp_polygon) == geo_polygon
      )
    end
  end

  describe "from_zip" do
    setup do
      [{name, proj, stream}] = ShapeShift.from_zip("#{__DIR__}/fixtures/hoods.zip")

      %{name: name, proj: proj, stream: stream}
    end
    test "that it returns the names properly", %{name: name} do
      assert name == "neighborhoods_orleans"
    end
    test "that it returns the proper proj data", %{proj: proj} do
      assert proj == "GEOGCS[\"GCS_North_American_1983\",DATUM[\"D_North_American_1983\",SPHEROID[\"GRS_1980\",6378137.0,298.257222101]],PRIMEM[\"Greenwich\",0.0],UNIT[\"Degree\",0.0174532925199433]]"
    end
    test "that the stream returned does not contain a headers row", %{stream: stream} do
      list_length =
        stream
        |> Enum.to_list()
        |> length()
      assert list_length == 74
    end
    test "that the attributes are contained as a map with header names as keys", %{stream: stream} do
      attribute_keys =
        stream
        |> Enum.to_list
        |> List.last
        |> Map.get(:attributes)
        |> Map.keys()

      assert attribute_keys == [
        "DIST", "DIST_NUM", "HS_DIS", "LBL_SHRT", "NBHD", "NBHD_NUM", "POLICE_DIS"]
    end
  end
end
