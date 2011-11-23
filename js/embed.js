/*
OpenLinkMap Copyright (C) 2010 Alexander Matheisen
This program comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it under certain conditions.
See olm.openstreetmap.de/info for details.
*/


// main function, creates map and layers, controls other functions
function createMap()
{
	root = "http://beta.openlinkmap.org/";
	loading = "<img class='loading' src='"+root+"/img/loading.gif'><br>"+translations['loading'];


	// get time offset to utc
	var now = new Date();
	offset = -(now.getTimezoneOffset() / 60);

	// projections
	wgs84 = new OpenLayers.Projection("EPSG:4326");
	google = new OpenLayers.Projection("EPSG:900913");

	// set language of openlayers
	OpenLayers.Lang.setCode(params['lang']);

	// creating a map
	map = new OpenLayers.Map('mapFrame',
	{
		controls: [],
		projection: google,
		displayProjection: wgs84,
		maxExtent: new OpenLayers.Bounds(-20037508.34, -20037508.34, 20037508.34, 20037508.34),
		numZoomLevels: 19,
		maxResolution: 156543.0339,
		units: 'meters'
	});

	// adding some controls
	map.addControl(new OpenLayers.Control.Attribution());
	map.addControl(new OpenLayers.Control.PanZoomBar());
	map.addControl(new OpenLayers.Control.ScaleLine({geodesic:true, maxWidth:200, bottomOutUnits:"", bottomInUnits:""}));
	map.addControl(new OpenLayers.Control.Navigation({dragPanOptions: {enableKinetic: true}}));

	// adding map layers
	var mapnikMap = new OpenLayers.Layer.OSM.Mapnik("Mapnik",
	{
		transitionEffect: 'resize',
		attribution: 'Map data &copy; <a href="http://www.openstreetmap.org/">OpenStreetMap</a> and contributors <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>'
	});

	// adding layers to map
	map.addLayers([mapnikMap]);


	// create popup
	if (params['id'] && params['type'])
	{
		map.setCenter(getMapLatLon(params['lat'], params['lon']), 13);
		var popupPosition = new OpenLayers.LonLat(params['lon'], params['lat']);
		var popup = createPopup(params['id'], params['type'], params['lat'], params['lon']);
	}
}


// shorter than document.get... everywhere
function gEBI(id)
{
	return document.getElementById(id);
}


// returns the current map bbox
function getBounds()
{
	return map.getExtent().transform(map.getProjectionObject(), wgs84).toArray();
}


// returns a new openlayers position, transformed from 4326/WGS84 to map's projection
function getMapLatLon(lat, lon)
{
	return new OpenLayers.LonLat(lon, lat).transform(wgs84, map.getProjectionObject());
}


// updates map's center
function updateMap()
{
	map.updateSize();
	map.setCenter(map.getCenter(), map.getZoom());
}


// removes given popup from map
function hidePopup(feature, popup)
{
	map.removePopup(feature.cluster[0].popup);
}


// creates a popup at a given position
function createPopup(id, type, lat, lon)
{
	// create popup
	var popup = new OpenLayers.Popup.FramedCloud("popup", getMapLatLon(lat, lon), null, loading, {size: new OpenLayers.Size(6,6),offset: new OpenLayers.Pixel(-3,-3)}, true, function(){map.removePopup(popup);});
	map.addPopup(popup);

	// request details for popup
	var handler = function(request)
		{
			var content = request.responseText;

			if (content != "NULL")
			{
				// set popup content
				popup.setContentHTML(content);
				map.removePopup(popup);
				map.addPopup(popup);
				alert(map.getPixelFromLonLat(map.getCenter()).y+(popup.size.w));
				map.setCenter(
					map.getLonLatFromPixel(
						map.getPixelFromLonLat(map.getCenter()).x-(popup.size.w),
						map.getPixelFromLonLat(map.getCenter()).y-(popup.size.h)
					),
				  13
				);
			}
			else
				map.removePopup(popup);
		}
	requestApi("details", "id="+id+"&type="+type+"&format=text&offset="+offset+"&lang="+params['lang'], handler);
}


// perform a synchron API request
function requestApi(file, query, handler)
{
	if (typeof handler == 'undefined')
		return OpenLayers.Request.GET({url: root+'api/'+file+'.php?'+query, async: false});
	else
		return OpenLayers.Request.GET({url: root+'api/'+file+'.php?'+query, async: true, success: handler});
}


// builds a lat-lon url parameter
function queryLatLon(lat, lon)
{
	return "lat="+lat+"&lon="+lon;
}


// builds a lat-lon url parameter with zoom
function queryLatLonZoom(lat, lon, zoom)
{
	return queryLatLon(lat, lon)+"&zoom="+zoom;
}