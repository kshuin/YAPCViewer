//
//  YVTalkListViewController.m
//  YAPCViewer
//
//  Created by Koichi Sakata on 8/3/13.
//  Copyright (c) 2013 www.huin-lab.com. All rights reserved.
//

#import "YVTalkListViewController.h"

#import "HIDataStoreManager.h"
#import "YVModels.h"
#import "YVTalks.h"

#import "YVTalkDetailViewController.h"

#import "YVEventDayView.h"
#import "YVTalkCell.h"
#import "YVSectionHeader.h"

static NSString *const kYVTalkListTalkCellIdentifier = @"kYVTalkListTalkCellIdentifier";
static NSString *const kYVTalkListTalksCacheName = @"kYVTalkListTalksCacheName";

static NSString *const kYVTalkListPushToDetailSegueIdentifier = @"PushToTalkDetailView";

static NSString *const kYVTalkListFirstDateString   = @"2013-09-19";
static NSString *const kYVTalkListSecondDateString  = @"2013-09-20";
static NSString *const kYVTalkListThirdDateString   = @"2013-09-21";

@interface YVTalkListViewController ()
< NSFetchedResultsControllerDelegate,
  UISearchDisplayDelegate,
  YVEventDayViewDelegate>

@property (nonatomic, strong) NSFetchedResultsController *frController;
@property (nonatomic, strong) UISearchDisplayController *searchController;
@property (nonatomic, strong) NSArray *filteredItems;

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet YVEventDayView *eventDayView;

- (NSFetchedResultsController *)_frControllerForQuery:(NSString *)query;
- (NSArray *)_filteredItemForQuery:(NSString *)query;

@end

@implementation YVTalkListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationController.tabBarController.tabBar.clipsToBounds = YES;
    self.view.backgroundColor = [YVTalkCell backgroundColor];

    self.tableView.backgroundView = [[UIView alloc] initWithFrame:self.tableView.bounds];
    self.tableView.backgroundView.backgroundColor = [YVTalkCell backgroundColor];

    NSArray *eventDays = @[kYVTalkListFirstDateString,
                           kYVTalkListSecondDateString,
                           kYVTalkListThirdDateString];

    [self.eventDayView setEventDays:eventDays];
    self.eventDayView.delegate = self;

    UISearchBar *searchBar = [[UISearchBar alloc] init];
    searchBar.frame = CGRectMake(0.0f, 0.0f, CGRectGetWidth(self.tableView.bounds), 44.0f);
    searchBar.tintColor = [UIColor colorForHex:@"#d5d5d5"];
    self.tableView.tableHeaderView = searchBar;

    self.searchController = [[UISearchDisplayController alloc] initWithSearchBar:searchBar
                                                              contentsController:self];
    self.searchController.delegate = self;
    self.searchController.searchResultsDataSource = self;
    self.searchController.searchResultsDelegate = self;

    if(!self.frController){
        self.frController = [self _frControllerForQuery:eventDays[0]];
    }

    NSError *fetchError = nil;
    if(![self.frController performFetch:&fetchError]){
        NSLog(@"FETCH ERROR : %@", fetchError);
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [[YVTalks new] fetchAllTalksWithHandler:^(NSDictionary *dataDict, NSError *error) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([segue.identifier isEqualToString:kYVTalkListPushToDetailSegueIdentifier]){
        NSAssert([sender isKindOfClass:[YVTalk class]], @"");

        YVTalkDetailViewController *vc;
        vc = (YVTalkDetailViewController *)segue.destinationViewController;
        vc.talk = (YVTalk *)sender;
    }
}

- (NSFetchedResultsController *)_frControllerForQuery:(NSString *)query
{
    [NSFetchedResultsController deleteCacheWithName:kYVTalkListTalksCacheName];
    
    NSFetchRequest *fr = [YVTalks talksRequestForDate:query];
    NSManagedObjectContext *moc = [HIDataStoreManager sharedManager].mainThreadMOC;

    NSFetchedResultsController *frController = nil;
    frController = [[NSFetchedResultsController alloc] initWithFetchRequest:fr
                                                       managedObjectContext:moc
                                                         sectionNameKeyPath:@"start_time"
                                                                  cacheName:kYVTalkListTalksCacheName];
    frController.delegate = self;

    return frController;
}

- (NSArray *)_filteredItemForQuery:(NSString *)query
{
    NSParameterAssert(query);

    NSArray *items = [self.frController fetchedObjects];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title contains[cd] %@ OR title_en contains[cd] %@", query, query];
    items = [items filteredArrayUsingPredicate:predicate];

    return items;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark - YVEventDayViewDelegate
////////////////////////////////////////////////////////////////////////////////

- (void)eventDayView:(YVEventDayView *)eventDayView
       dayDidChanged:(NSString *)dayString
{
    self.frController = [self _frControllerForQuery:dayString];

    NSError *fetchError = nil;
    if(![self.frController performFetch:&fetchError]){
        NSLog(@"FETCH ERROR : %@", fetchError);
    }

    [self.tableView reloadData];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark - UITableViewDataSource
////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if(self.tableView == tableView){
        return self.frController.sections.count;
    }

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(self.tableView == tableView){
        id<NSFetchedResultsSectionInfo> sectionInfo;
        sectionInfo = self.frController.sections[section];
        return [[sectionInfo objects] count];
    }

    return [self.filteredItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    YVTalkCell *cell;
    cell = [tableView dequeueReusableCellWithIdentifier:kYVTalkListTalkCellIdentifier];
    if(nil == cell){
        cell = [[YVTalkCell alloc] initWithStyle:UITableViewCellStyleDefault
                                 reuseIdentifier:kYVTalkListTalkCellIdentifier];
    }

    YVTalk *talk = nil;
    if(self.tableView == tableView){
        talk = [self.frController objectAtIndexPath:indexPath];
    }else{
        talk = [self.filteredItems objectAtIndex:indexPath.row];
    }
    
    NSParameterAssert(talk);
    [cell loadDataFromTalk:talk];

    return cell;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark - UITableViewDelegate
////////////////////////////////////////////////////////////////////////////////

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];

    YVTalk *talk;
    if(self.tableView == tableView){
        talk = [self.frController objectAtIndexPath:indexPath];
    }else{
        talk = [self.filteredItems objectAtIndex:indexPath.row];
    }

    [self performSegueWithIdentifier:@"PushToTalkDetailView"
                              sender:talk];
}

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [YVTalkCell cellHeight];
}

- (UIView *)tableView:(UITableView *)tableView
viewForHeaderInSection:(NSInteger)section
{
    id<NSFetchedResultsSectionInfo> sectionInfo;
    sectionInfo = self.frController.sections[section];

    YVSectionHeader *header = [[YVSectionHeader alloc] initWithFrame:CGRectZero];
    header.frame = CGRectMake(0.0f, 0.0f, CGRectGetWidth(self.tableView.bounds), 23.0f);

    [header setSectionTitle:[sectionInfo name]];
    return header;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSFethedResultsControllerDelegate
////////////////////////////////////////////////////////////////////////////////

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if(type == NSFetchedResultsChangeInsert){
        [self.tableView insertRowsAtIndexPaths:@[newIndexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
    }else if(type == NSFetchedResultsChangeUpdate){
        [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
    }else if(type == NSFetchedResultsChangeDelete){
        [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark - UISearchDispalyDelegate
////////////////////////////////////////////////////////////////////////////////

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller
    shouldReloadTableForSearchString:(NSString *)searchString
{
    NSString *query = controller.searchBar.text;
    query = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    if(query < 0){
        return NO;
    }

    self.filteredItems = [self _filteredItemForQuery:query];
    return YES;
}

@end