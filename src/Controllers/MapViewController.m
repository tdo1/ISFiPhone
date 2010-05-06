//
//  MapViewController.m
//  Ile sans fil
//
//  Created by Oli on 11/06/09.
//  Copyright 2009 Kolt Production. All rights reserved.
//

#import <SystemConfiguration/SystemConfiguration.h>
#import "MapViewController.h"
#import "LocationAnnotation.h"
#import "googleMapsAPI.h"
#import "Hotspot.h"
#import "HotspotInfosViewController.h"
#import "ISFAppDelegate.h"
#import "LoadingOverlay.h"
#import "ConnectionViewController.h"


#define ZOOM_DEFAULT 1000		// 1000 meters
#define ZOOM_INCREMENT 0.01
#define MAX_SPAN_DELTA 0.4
#define DELTA_UPDATE 0.1

#define MAX_LOCATIONS 280
#define NB_SHOW_BANKS 3

#define BOUND_X_MIN -10
#define BOUND_X_MAX 330
#define BOUND_Y_MIN 0
#define BOUND_Y_MAX 400


@interface MapViewController (Internal)

- (BOOL)isConnectionAvailable;

- (void)displaySearchingView;
- (void)removeSearchingView;
- (void)displayNoHotspotView;
- (void)removeNoHotspotView;

- (void)removeAllAnnotations;
- (void)addHotspots;
- (void)checkLocationsInView;

- (void)updateMapLocations;
- (void)mapZoomOut;
- (void)mapZoomToLocation:(CLLocationCoordinate2D)position animated:(BOOL)animated;

- (void)searchAddress;
@end


@implementation MapViewController

@synthesize hotspotArray,filteredListContent, savedSearchTerm, searchWasActive;

- (void)fetchHotspots {
	NSString *urlString = @"http://auth.ilesansfil.org/hotspot_status.php?format=XML";
	NSURL *url = [NSURL URLWithString:urlString];
	XMLReader *xmlReader = [[[XMLReader alloc] init] autorelease];
	xmlReader.delegate = self;
	[xmlReader parseXMLFileAtURL:url parseError:nil];
}

- (void)XMLReaderDidFinishParsing {
	if (isFirstLaunch == YES) {
		[self mapZoomToLocation:[[map userLocation] coordinate] animated:YES];
		isFirstLaunch = NO;
		[[LoadingOverlay overlayInstance] hide];
	}
	[self removeAllAnnotations];
//	[self performSelectorOnMainThread:@selector(addHotspots) withObject:nil waitUntilDone:NO];
	[self addHotspots];
	
	
	hotspotArray=[[NSMutableArray alloc] init];
		[self setHotspotArray:[NSMutableArray arrayWithArray:[Hotspot findAll]]];
		[tableViewHotspot reloadData];	
	
	
	// create a filtered list that will contain products for the search results table.
	self.filteredListContent = [NSMutableArray arrayWithCapacity:[hotspotArray count]];
	
	// restore search settings if they were saved in didReceiveMemoryWarning.
    if (self.savedSearchTerm)
	{
        [self.searchDisplayController setActive:self.searchWasActive];
		//   [self.searchDisplayController.searchBar setSelectedScopeButtonIndex:self.savedScopeButtonIndex];
        [self.searchDisplayController.searchBar setText:savedSearchTerm];
        
        self.savedSearchTerm = nil;
    }
//	[tableViewHotspot reloadData];
	tableViewHotspot.scrollEnabled = YES;

	
}
- (void)XMLReaderDidFailParsing {
}

- (void)viewDidLoad {
   [super viewDidLoad];
	
	searchWasActive=NO;
	
	operationQueue = [[NSOperationQueue alloc] init];
	[operationQueue setMaxConcurrentOperationCount:1];

//	[self fetchHotspots];
	if ([[Hotspot findAll] count] == 0) {
		isFirstLaunch = YES;
		[[LoadingOverlay overlayInstance] showMessage:NSLocalizedString(@"Loading...", @"") inViewController:[self parentViewController]];
		[self fetchHotspots];
	}
	else {
		NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(fetchHotspots) object:nil];
		[operationQueue addOperation:operation];
		[operation release];
	}

	searchingView.hidden = YES;
	
	locatingLabel.text = NSLocalizedString(@"Locating...", @"");
	
	initialized = NO;
	[searchingView removeFromSuperview];

	// Initialize the current location
	[[map userLocation] setTitle:NSLocalizedString(@"You are here", @"")];

	// Initialize the search location
	searchLocation = [[LocationAnnotation alloc] init];

/*	// Initialize the Google Maps API
	gMapsAPI = [[googleMapsAPI alloc] init];
	gMapsAPI.delegate = self;*/

	// Set the search bar keyboard appearance
	for (UIView *v in addressSearchBar.subviews) {
		if ([v isKindOfClass: [UITextField class]]) {
			((UITextField *)v).keyboardAppearance = UIKeyboardAppearanceAlert;
			break;
		}
	}
	
//	addressSearchBar.showsCancelButton=false;
//	addressSearchBar.autoresizesSubviews=false;
	
	UIBarButtonItem *showListButton = [[UIBarButtonItem alloc]
								   initWithImage:[UIImage imageNamed:@"tab-list2.png"]
								   style:UIBarButtonItemStyleBordered
								   target:self
								   action:@selector(showList)];
	
	[_navItem setLeftBarButtonItem:showListButton];
	
	hotspotArray=[[NSMutableArray alloc] init];
	[self setHotspotArray:[NSMutableArray arrayWithArray:[Hotspot findAll]]];
	[tableViewHotspot reloadData];	
	
	
	
	// create a filtered list that will contain products for the search results table.
	self.filteredListContent = [NSMutableArray arrayWithCapacity:[hotspotArray count]];
	
	//
	//[self.searchDisplayController setActive:false animated:false];
	
	NSLog(@"viewdidload");
	NSLog(@"search was active : %@", searchWasActive?@"YES":@"NO");
	
	
}


- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	if([self isConnectionAvailable] == NO) {
		ConnectionViewController *connectionView= [[[ConnectionViewController alloc] initWithNibName:@"ConnectionViewController" bundle:nil] autorelease];
		[self presentModalViewController:connectionView animated:NO];
	}
	
	needsZoomOut = YES;
	

	// restore search settings if they were saved in didReceiveMemoryWarning.
    if (self.savedSearchTerm)
	{
     /*   [self.searchDisplayController setActive:self.searchWasActive];
		//   [self.searchDisplayController.searchBar setSelectedScopeButtonIndex:self.savedScopeButtonIndex];
        [self.searchDisplayController.searchBar setText:savedSearchTerm];
        [self.searchDisplayController.searchBar setShowsCancelButton:false];
		[self.searchDisplayController.searchBar setShowsBookmarkButton:false];
		[self.searchDisplayController.searchBar setShowsScopeBar:false];*/
	
        self.savedSearchTerm = nil;
    }
	//	[tableViewHotspot reloadData];
	//tableViewHotspot.scrollEnabled = YES;
/*	[self.searchDisplayController.searchBar setShowsCancelButton:false];
	[self.searchDisplayController.searchBar setShowsBookmarkButton:false];
	[self.searchDisplayController.searchBar setShowsScopeBar:false];*/
	
	
		//[self.searchDisplayController.searchBar resignFirstResponder];
	NSLog(@"viewwillappear");
	NSLog(@"search was active : %@", searchWasActive?@"YES":@"NO");
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	
	[self removeAllAnnotations];
}

- (void)viewDidUnload {
}

- (void)dealloc {
	[map release];
//	[gMapsAPI release];

	
	[operationQueue release];
	[noHotspotView release];
	[searchingView release];
	[super dealloc];
}


#pragma mark -
#pragma mark Internet Connection

- (BOOL)isConnectionAvailable {
	static BOOL checkNetwork = YES;
	static BOOL available = NO;
	if (checkNetwork) { // Since checking the reachability of a host can be expensive, cache the result and perform the reachability check once.
		checkNetwork = NO;
		
		Boolean success;    
		const char *host_name = "google.com";
		
		SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, host_name);
		SCNetworkReachabilityFlags flags;
		success = SCNetworkReachabilityGetFlags(reachability, &flags);
		available = success && (flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired);
		CFRelease(reachability);
	}
	return available;
}


#pragma mark -
#pragma mark Notifications Views

- (void)displaySearchingView {
	searchingLocation = YES;
//	[self.view addSubview:searchingView];
}
- (void)removeSearchingView {
	[searchingView removeFromSuperview];
	if(searchingLocation == YES) {
		searchingLocation = NO;
		[map selectAnnotation:searchLocation animated:YES];
	}
	if(locatingMe == YES) {
		locatingMe = NO;
		[map selectAnnotation:[map userLocation] animated:YES];
	}
}


- (void)displayNoHotspotView {
	if(initialized == NO || noHotspotView != nil || updatingLocations == YES) return;
	noHotspotView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 24)];
	UIImageView *background = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 24)];
	background.image = [UIImage imageNamed:@"alert_back-red.png"];
	[noHotspotView addSubview:background];
	[background release];
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 2, 300, 20)];
	label.backgroundColor = [UIColor clearColor];
	label.textColor = [UIColor whiteColor];
	label.font = [UIFont boldSystemFontOfSize:13];
	label.shadowColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.8];
	label.shadowOffset = CGSizeMake(0, -1);
	label.textAlignment = UITextAlignmentCenter;
	label.text = [NSString stringWithString:NSLocalizedString(@"There are no location in the area", @"")];
	[noHotspotView addSubview:label];
	[label release];
	[map addSubview:noHotspotView];
}
- (void)removeNoHotspotView {
	if(noHotspotView == nil) return;
	[noHotspotView removeFromSuperview];
	[noHotspotView release];
	noHotspotView = nil;
}

#pragma mark -
#pragma mark Annotations

- (void)removeAllAnnotations {
	NSArray *annotations = [[NSArray alloc] initWithArray:map.annotations];
	NSEnumerator *enumerator = [annotations objectEnumerator];
	LocationAnnotation *location;
	while (location = [enumerator nextObject]) {
		if(location == (LocationAnnotation *)[map userLocation]) {
			currentLocationInMap = YES;
			continue;
		}
		if(location == searchLocation) {
			continue;
		}
		[map removeAnnotation:location];
	}
	[annotations release];
}

- (void)addHotspots {
	for (Hotspot *hotspot in [Hotspot findAll]) {
		LocationAnnotation *annotation = [[[LocationAnnotation alloc] init] autorelease];
		annotation.title = hotspot.name;
		annotation.subtitle = [hotspot fullAddressOneLine];
		CLLocationCoordinate2D coords;
		coords.latitude	= [hotspot.latitude doubleValue];
		coords.longitude	= [hotspot.longitude doubleValue];
		annotation.coordinate = coords;
		annotation.hotspot = hotspot;
		[map addAnnotation:annotation];
	}
}

- (void)checkLocationsInView {
	locationInView = NO;
	for (LocationAnnotation *annotation in [map annotations]) {
		if (annotation == (LocationAnnotation *)[map userLocation] || annotation == searchLocation) continue;
		CLLocationCoordinate2D coords = annotation.coordinate;
		CGPoint point = [map convertCoordinate:coords toPointToView:map];
		if(point.x > BOUND_X_MIN && point.x < BOUND_X_MAX && point.y > BOUND_Y_MIN && point.y < BOUND_Y_MAX) {
			locationInView = YES;
			[self removeNoHotspotView];
			return;
		}
	}
}


#pragma mark -
#pragma mark Map Kit

// Zoom out by ZOOM_INCREMENT
- (void)mapZoomOut {
	MKCoordinateRegion region = map.region;
	if(region.span.latitudeDelta >= MAX_SPAN_DELTA || region.span.longitudeDelta >= MAX_SPAN_DELTA) {
		needsZoomOut = NO;
		return;
	}
	region.span.latitudeDelta += ZOOM_INCREMENT;
	region.span.longitudeDelta += ZOOM_INCREMENT;
	[map setRegion:region animated:YES];
}

// Zoom to a specified location
- (void)mapZoomToLocation:(CLLocationCoordinate2D)position animated:(BOOL)animated {
	if (position.latitude == -180 || position.longitude == -180) return;
	MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(position, ZOOM_DEFAULT, ZOOM_DEFAULT);
	[map setRegion:region animated:animated];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {
	if (isFirstLaunch) return nil;
	if(annotation == [mapView userLocation]) {
		if(initialized == NO) {
			[self mapZoomToLocation:[[map userLocation] coordinate] animated:YES];
		}
		return nil;
	}

	static NSString *annotationIdentifier = @"DefaultPinID";
	MKAnnotationView *mkav = (MKAnnotationView *) [mapView dequeueReusableAnnotationViewWithIdentifier:annotationIdentifier];

	if (mkav == nil) {
		 mkav = [[[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationIdentifier] autorelease];
	} else {
		 mkav.annotation = annotation;
	}
	
	mkav.canShowCallout = TRUE;
	
	if ((LocationAnnotation *)annotation == searchLocation) mkav.image = [UIImage imageNamed:@"pin-search.png"];
	else {
		mkav.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
		if ([((LocationAnnotation *)annotation).hotspot status] == kHotspotStatusUnknow) mkav.image = [UIImage imageNamed:@"pin-unknown.png"];
		if ([((LocationAnnotation *)annotation).hotspot status] == kHotspotStatusDown) mkav.image = [UIImage imageNamed:@"pin-down.png"];
		if ([((LocationAnnotation *)annotation).hotspot status] == kHotspotStatusUp) mkav.image = [UIImage imageNamed:@"pin-up.png"];
	}

	return mkav;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
	//Action du bouton info des annotations
	HotspotInfosViewController *infosController = [[[HotspotInfosViewController alloc] initWithBackImageNamed:NSLocalizedString(@"btn-back-map", @"")] autorelease];
	infosController.hotspot = ((LocationAnnotation *)(view.annotation)).hotspot;
	infosController.currentCoords = mapView.userLocation.coordinate;
	[self presentModalViewController:infosController animated:YES];
}
- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views {
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
}
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
	if(initialized == NO && map.region.span.latitudeDelta < MAX_SPAN_DELTA) {
		[self addHotspots];
		initialized = YES;
	}
	if(initialized == NO || loadingMap == YES) return;

	if(searchingLocation == NO) {
		[self checkLocationsInView];
		if (locationInView == NO) [self mapZoomOut];
	}

	// Is there any location in the area
	if(locationInView == NO && (mapView.region.span.latitudeDelta >= MAX_SPAN_DELTA || mapView.region.span.longitudeDelta >= MAX_SPAN_DELTA)) {
		[self displayNoHotspotView];
	}
	else [self removeNoHotspotView];
}

- (void)mapViewDidFailLoadingMap:(MKMapView *)mapView withError:(NSError *)error {
}

- (void)mapViewWillStartLoadingMap:(MKMapView *)mapView {
	[[ISFAppDelegate appDelegate] showNetworkActivity:YES];
	loadingMap = YES;
}
- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView {
	[[ISFAppDelegate appDelegate] showNetworkActivity:NO];
	loadingMap = NO;
	if(searchingLocation == YES) {
		[self removeSearchingView];
		[self mapZoomToLocation:searchLocation.coordinate animated:YES];
	}
	else {
		[self checkLocationsInView];
		if (locationInView == NO) [self mapZoomOut];
	}

	[map showsUserLocation];
	
}


#pragma mark -
#pragma mark Location

- (IBAction)locateMe {
	needsZoomOut = YES;
	locatingMe = YES;
	[self mapZoomToLocation:[[map userLocation] coordinate] animated:NO];
	[map selectAnnotation:[map userLocation] animated:YES];
}


#pragma mark -
#pragma mark Search Bar Delegate

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchWasActive = NO;
	[addressSearchBar setShowsCancelButton:NO animated:YES];
	[addressSearchBar resignFirstResponder];
	
	
}
/*
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	searchLocation.title = [NSString stringWithString:searchBar.text];
	[searchBar resignFirstResponder];
	[self searchAddress];
}

- (void)searchAddress {
	if(addressSearchBar.text == nil) return;
	[self displaySearchingView];
	addressSearchBar.text = [NSString stringWithFormat:@"%@, Montreal, QC, Canada", addressSearchBar.text];
	
	// Send an asynchronous request to the Google Maps API
	NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:gMapsAPI selector:@selector(getCoordFromAddress:) object:addressSearchBar.text];
	[operationQueue addOperation:operation];
	[operation release];
}

#pragma mark -
#pragma mark Google Maps API

- (void)googleMapsAPIDidFindCoordinates:(CLLocationCoordinate2D)coordinates {
	if(searchLocation.coordinate.latitude == coordinates.latitude && searchLocation.coordinate.longitude == coordinates.longitude) [self removeSearchingView];
	else searchLocation.coordinate = coordinates;
	[map addAnnotation:searchLocation];
	[map setCenterCoordinate:coordinates animated:YES];
}
- (void)googleMapsAPIDidFailWithMessage:(NSString *)message {
	searchLocation.title = @"";
	[self removeSearchingView];
}
 */

-(CLLocationCoordinate2D) getCurrentCoordinate {
	CLLocationCoordinate2D coordinate= [[map userLocation] coordinate];
	
	return coordinate;
	
}
- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar {
	
	//This method is called again when the user clicks back from teh detail view.
	//So the overlay is displayed on the results, which is something we do not want to happen.
	//if(searchWasActive)
	//	return;
	
	//Add the overlay view.
	/*if(ovController == nil)
		ovController = [[OverlayViewController alloc] initWithNibName:@"OverlayView" bundle:[NSBundle mainBundle]];
	
	CGFloat yaxis = self.navigationController.navigationBar.frame.size.height;
	CGFloat width = self.view.frame.size.width;
	CGFloat height = self.view.frame.size.height;
	
	//Parameters x = origion on x-axis, y = origon on y-axis.
	CGRect frame = CGRectMake(0, yaxis, width, height);
	ovController.view.frame = frame;	
	ovController.view.backgroundColor = [UIColor grayColor];
	ovController.view.alpha = 0.5;
	
	ovController.rvController = self;
	
	[self.tableView insertSubview:ovController.view aboveSubview:self.parentViewController.view];
	*/
	//searchWasActive = YES;
	
	//letUserSelectRow = NO;
	//tableViewHotspot.scrollEnabled = NO;
	[addressSearchBar setShowsCancelButton:YES animated:YES];
	if(!map.hidden)
	{
	[self showList];
	}
	//Add the done button.
/*	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] 
											   initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
											   target:self action:@selector(doneSearching_Clicked:)] autorelease];*/
	
	NSLog(@"searchdidbeginediting");
	NSLog(@"search was active : %@", searchWasActive?@"YES":@"NO");
}

- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText {
	
	//Remove all objects first.
	[self.filteredListContent removeAllObjects];
	
	if([addressSearchBar.text length] > 0) {
		
		//[ovController.view removeFromSuperview];
		searchWasActive = YES;
	//	letUserSelectRow = YES;
	//	tableViewHotspot.scrollEnabled = YES;
	
		[self searchTableView:addressSearchBar.text];
	}
	else {
		
		//[self.tableView insertSubview:ovController.view aboveSubview:self.parentViewController.view];
		
		searchWasActive = NO;
	//	[addressSearchBar resignFirstResponder];
		//letUserSelectRow = NO;
		//tableViewHotspot.scrollEnabled = NO;
	}
	NSLog(@"textdidchange");
	NSLog(@"search was active : %@", searchWasActive?@"YES":@"NO");
	[tableViewHotspot reloadData];
}
/*
- (void) searchBarSearchButtonClicked:(UISearchBar *)theSearchBar {
	
	//[self searchTableView];
	
	[self searchTableView:addressSearchBar.text];
}
/*
- (void) searchTableView {
	
	NSString *searchText = searchBar.text;
	NSMutableArray *searchArray = [[NSMutableArray alloc] init];
	
	for (NSDictionary *dictionary in listOfItems)
	{
		NSArray *array = [dictionary objectForKey:@"Countries"];
		[searchArray addObjectsFromArray:array];
	}
	
	for (NSString *sTemp in searchArray)
	{
		NSRange titleResultsRange = [sTemp rangeOfString:searchText options:NSCaseInsensitiveSearch];
		
		if (titleResultsRange.length > 0)
			[copyListOfItems addObject:sTemp];
	}
	
	[searchArray release];
	searchArray = nil;
}*/

/*- (void) doneSearching_Clicked:(id)sender {
	
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	
	letUserSelectRow = YES;
	searching = NO;
	self.navigationItem.rightBarButtonItem = nil;
	self.tableView.scrollEnabled = YES;
	
	[ovController.view removeFromSuperview];
	[ovController release];
	ovController = nil;
	
	[self.tableView reloadData];
}
*/
-(void)searchTableView:(NSString*)searchText /*scope:(NSString*)scope*/
{
	/*
	 Update the filtered array based on the search text and scope.
	 */
	
	[self.filteredListContent removeAllObjects]; // First clear the filtered array.
	
	/*
	 Search the main list for products whose type matches the scope (if selected) and whose name matches searchText; add items that match to the filtered array.
	 */
	/*	for (Hotspot *hotspot in hotspotArray)
	 {
	 
	 NSComparisonResult result = [hotspot.name compare:searchText options:(NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch) range:NSMakeRange(0, [searchText length])];
	 if (result == NSOrderedSame)
	 {
	 [self.filteredListContent addObject:hotspot];
	 }
	 
	 }
	 */
	
	for (Hotspot *hotspot in hotspotArray)
	{
		NSRange titleResultsRange = [hotspot.name rangeOfString:searchText options:NSCaseInsensitiveSearch];
		
		if (titleResultsRange.length > 0)
			[self.filteredListContent addObject:hotspot];
	}
	NSLog(@"searchtableview");
	NSLog(@"search was active : %@", searchWasActive?@"YES":@"NO");
	
}


#pragma mark -
#pragma mark Content Filtering
/*
- (void)filterContentForSearchText:(NSString*)searchText /*scope:(NSString*)scope*/
/*{
	/*
	 Update the filtered array based on the search text and scope.
	 */
	
/*	[self.filteredListContent removeAllObjects]; // First clear the filtered array.
	
	/*
	 Search the main list for products whose type matches the scope (if selected) and whose name matches searchText; add items that match to the filtered array.
	 */
/*	for (Hotspot *hotspot in hotspotArray)
	{
		
			NSComparisonResult result = [hotspot.name compare:searchText options:(NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch) range:NSMakeRange(0, [searchText length])];
            if (result == NSOrderedSame)
			{
				[self.filteredListContent addObject:hotspot];
            }
		
	}
	*/
	
/*	for (Hotspot *hotspot in hotspotArray)
	{
		NSRange titleResultsRange = [hotspot.name rangeOfString:searchText options:NSCaseInsensitiveSearch];
		
		if (titleResultsRange.length > 0)
			[self.filteredListContent addObject:hotspot];
	}

}
*/
#pragma mark -
#pragma mark UISearchDisplayController Delegate Methods
/*
- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText {
	NSLog(@"RRRRRRRRRRRRRR");	
	
}
/*
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
	//NSLog(@"RRRRRRRRRRRRRR");	
	[self.searchDisplayController.searchBar setShowsCancelButton:false];
	[self.searchDisplayController.searchBar setShowsBookmarkButton:false];
	[self.searchDisplayController.searchBar setShowsScopeBar:false];
	[self.searchDisplayController.searchBar setShowsCancelButton:NO animated:NO];
	
	return YES;
	
}
- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
	//NSLog(@"RRRRRRRRRRRRRR");	
	[self.searchDisplayController.searchBar setShowsCancelButton:false];
	[self.searchDisplayController.searchBar setShowsBookmarkButton:false];
	[self.searchDisplayController.searchBar setShowsScopeBar:false];
		[self.searchDisplayController.searchBar setShowsCancelButton:false animated:false];
	//	[self.searchDisplayController.searchBar set];
		
	return YES;
	
}
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	//NSLog(@"RRRRRRRRRRRRRR");	
	[self.searchDisplayController.searchBar setShowsCancelButton:false];
	[self.searchDisplayController.searchBar setShowsBookmarkButton:false];
	[self.searchDisplayController.searchBar setShowsScopeBar:false];
		[self.searchDisplayController.searchBar setShowsCancelButton:false animated:false];
	
	//return YES;
}
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	//NSLog(@"RRRRRRRRRRRRRR");	
	[self.searchDisplayController.searchBar setShowsCancelButton:false];
	[self.searchDisplayController.searchBar setShowsBookmarkButton:false];
	[self.searchDisplayController.searchBar setShowsScopeBar:false];
		[self.searchDisplayController.searchBar setShowsCancelButton:false animated:false];
	
	//return YES;

}
- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
   
	
	[self filterContentForSearchText:searchString];
    
    // Return YES to cause the search result table view to be reloaded.
	[self.searchDisplayController.searchBar setShowsCancelButton:false];
	[self.searchDisplayController.searchBar setShowsBookmarkButton:false];
	[self.searchDisplayController.searchBar setShowsScopeBar:false];
	
    return YES;
}


- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    [self filterContentForSearchText:[self.searchDisplayController.searchBar text]];
    
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}
*/




- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	
	//return [hotspotArray count];
	
	//if (tableView == self.searchDisplayController.searchResultsTableView)
	if(searchWasActive==YES)
	{
        return [self.filteredListContent count];
    }
	else
	{
        return [hotspotArray count];
		
    }
	
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	return 60.0f;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	NSLog(@"cellforrowindexpathDEBUT");
	NSLog(@"search was active : %@", searchWasActive?@"YES":@"NO");
	
	static NSString *CellIdentifier = @"identifier";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
		
	}
	Hotspot *hotspot = nil;
	//if (tableView == self.searchDisplayController.searchResultsTableView)
	if(searchWasActive==YES)
	{
        hotspot = (Hotspot *)[self.filteredListContent objectAtIndex:indexPath.row];
		
    }
	else
	{
        hotspot = (Hotspot *)[hotspotArray objectAtIndex:indexPath.row];
    }
	
	//Hotspot *hotspot = (Hotspot *)[hotspotArray objectAtIndex:indexPath.row];

	NSString *address=[[hotspot civicNumber] stringByAppendingString:@" "];
	cell.detailTextLabel.text=[address stringByAppendingString:[hotspot streetAddress]];

	cell.textLabel.text = [hotspot name];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	NSLog(@"cellforrowindexpathFIN");
	NSLog(@"search was active : %@", searchWasActive?@"YES":@"NO");
	
	return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	NSLog(@"SELECTROWDEBUT");
	NSLog(@"search was active : %@", searchWasActive?@"YES":@"NO");
	
	//Hotspot *hotspot = (Hotspot *)[hotspotArray objectAtIndex:indexPath.row];
	Hotspot *hotspot = nil;
	//if (tableView == self.searchDisplayController.searchResultsTableView)
	if(searchWasActive==YES)
	{
        hotspot =  (Hotspot *)[self.filteredListContent objectAtIndex:indexPath.row];
		[addressSearchBar resignFirstResponder];
		//searchWasActive=NO;
		//[tableViewHotspot reloadData];
		
    }
	else
	{
        hotspot = (Hotspot *)[hotspotArray objectAtIndex:indexPath.row];
    }
	
		HotspotInfosViewController *infosController = [[[HotspotInfosViewController alloc] initWithBackImageNamed:NSLocalizedString(@"btn-back-list", @"")] autorelease];
		infosController.hotspot = hotspot;
		//infosController.currentCoords = mapView.userLocation.coordinate;
		
		infosController.currentCoords =[self getCurrentCoordinate];
		[self presentModalViewController:infosController animated:YES];
	NSLog(@"selectrowFIN");
	NSLog(@"search was active : %@", searchWasActive?@"YES":@"NO");
	
}

- (IBAction)showList {
	
	if(map.hidden)
	{
		map.hidden=false;
		searchingView.hidden=false;
		tableViewHotspot.hidden=true;
		UIBarButtonItem *nextButton = [[UIBarButtonItem alloc]
									   initWithImage:[UIImage imageNamed:@"tab-list2.png"]
									   style:UIBarButtonItemStyleBordered
									   target:self
									   action:@selector(showList)];
		
		[_navItem setLeftBarButtonItem:nextButton];
		[addressSearchBar setText:@""];
		
		[addressSearchBar resignFirstResponder];
		searchWasActive=NO;
		[tableViewHotspot reloadData];

	}else {
		map.hidden=true;
		searchingView.hidden=true;	
		tableViewHotspot.hidden=false;
		
		
		UIBarButtonItem *nextButton = [[UIBarButtonItem alloc]
									   initWithImage:[UIImage imageNamed:@"map.png"]
									   style:UIBarButtonItemStyleBordered
									   target:self
									   action:@selector(showList)];
		
		[_navItem setLeftBarButtonItem:nextButton];
	}

	
}

@end