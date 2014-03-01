//
//  WALMasterViewController.m
//  Wallabag
//
//  Created by Kevin Meyer on 19.02.14.
//  Copyright (c) 2014 Wallabag. All rights reserved.
//

#import "WALFeedTableViewController.h"
#import "WALArticleViewController.h"
#import "WALSettingsTableViewController.h"
#import "WALAddArticleTableViewController.h"
#import "WALArticle.h"
#import "WALSettings.h"

@interface WALFeedTableViewController ()
@property (strong) NSMutableArray* articles;
@property (strong) NSXMLParser* parser;
@property (strong) NSString* parser_currentString;
@property (strong) WALArticle* parser_currentArticle;
@property (strong) WALSettings* settings;
@end

@implementation WALFeedTableViewController

- (void)awakeFromNib
{
	[self.navigationController setToolbarHidden:true];
	self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"NavigationBarItem"]];
	
	self.refreshControl = [[UIRefreshControl alloc] init];
	[self.refreshControl addTarget:self action:@selector(updateArticles) forControlEvents:UIControlEventValueChanged];
	[super awakeFromNib];
	
	///! Disabled Add Article Button!
	self.navigationItem.rightBarButtonItem = nil;
	
	[self loadArticles];
	if (!self.articles)
	{
		self.articles = [NSMutableArray array];
	}
	
	self.settings = [WALSettings settingsFromSavedSettings];
	
	if (self.settings)
		[self updateArticles];
}

- (void) viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	if (!self.settings)
	{
		[self performSegueWithIdentifier:@"ModalToSettings" sender:self];
	}

}

- (void) didReceiveMemoryWarning
{
	[self.parser abortParsing];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.articles count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	WALArticle *currentArticle = [self.articles objectAtIndex:indexPath.row];
	
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ArticleCell" forIndexPath:indexPath];
	cell.textLabel.text = currentArticle.title;
//	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [currentArticle.link absoluteString]];
//	cell.detailTextLabel.text = [currentArticle getDateString];
	cell.detailTextLabel.text = @"";
	
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 60.0f;
}

#pragma mark - DataParser

- (void) updateArticles
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	[self.refreshControl beginRefreshing];
	
	NSString *urlString = [NSString stringWithFormat:@"%@/?feed&type=home&user_id=%ld&token=%@", [self.settings.wallabagURL absoluteString], (long) self.settings.userID, self.settings.apiToken];
	NSURL *url = [NSURL URLWithString:urlString];
		
	NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:20.0];
	
	[NSURLConnection sendAsynchronousRequest:urlRequest
									   queue:[NSOperationQueue mainQueue]
						   completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError)
	{
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
		[self.refreshControl endRefreshing];
		
		NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*) response;
		
		if (!connectionError && [response.MIMEType isEqualToString:@"application/rss+xml"] && httpResponse.statusCode > 199 && httpResponse.statusCode < 300)
		{
			[self.articles removeAllObjects];
			self.parser = [[NSXMLParser alloc] initWithData:data];
			self.parser.delegate = self;

			[self.parser parse];
		}
		else
		{
			//NSLog(@"Connection Error: %@", connectionError.description);
			NSLog(@"Status Code: %ld", (long)httpResponse.statusCode);
			NSLog(@"MIME Type: %@", [response MIMEType]);
			
			if (connectionError)
				[self informUserConnectionError:connectionError];
			
			else if (httpResponse.statusCode < 200 || httpResponse.statusCode > 299)
				[self informUserWrongServerAddress];
			
			else
				[self informUserWrongAuthentication];
		}
	}];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"item"])
	{
		self.parser_currentArticle = [[WALArticle alloc] init];
	}
	
	self.parser_currentString = nil;
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if ([elementName isEqualToString:@"item"])
	{
		[self.articles addObject:self.parser_currentArticle];
		self.parser_currentArticle = nil;
		
		
		///! Quick Fix for Memory Errors when parsing too large feeds.
		if ([self.articles count] > 50)
		{
			[parser abortParsing];
		}
	}
	else if ([elementName isEqualToString:@"title"])
	{
		self.parser_currentArticle.title = [self.parser_currentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];;
	}
	else if ([elementName isEqualToString:@"link"])
	{
		self.parser_currentArticle.link = [NSURL URLWithString:self.parser_currentString];
	}
	else if ([elementName isEqualToString:@"pubDate"])
	{
		[self.parser_currentArticle setDateWithString:self.parser_currentString];
	}
	else if ([elementName isEqualToString:@"description"])
	{
		self.parser_currentArticle.content = self.parser_currentString;
	}
	
	self.parser_currentString = nil;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	if (self.parser_currentString != nil)
		self.parser_currentString = [self.parser_currentString stringByAppendingString:string];
	else
		self.parser_currentString = string;
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
	self.parser_currentArticle = nil;
	self.parser_currentString = nil;
	self.parser = nil;
	
	[self afterParsingComplete];
}

- (void) afterParsingComplete
{
	[self saveArticles];
	[self.tableView reloadData];
	
	if ([self.articles count] == 0)
	{
		[self informUserNoArticlesInFeed];
	}
}

#pragma mark - Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"PushToArticle"])
	{
		NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
		[((WALArticleViewController*)segue.destinationViewController) setDetailArticle:self.articles[indexPath.row]];
		[[self.tableView cellForRowAtIndexPath:indexPath] setSelected:false animated:TRUE];
	}
	else if ([[segue identifier] isEqualToString:@"ModalToSettings"])
	{
		WALSettingsTableViewController *targetViewController = ((WALSettingsTableViewController*)[segue.destinationViewController viewControllers][0]);
		targetViewController.delegate = self;
		[targetViewController setSettings:self.settings];
	}
	else if ([[segue identifier] isEqualToString:@"ModalToAddArticle"])
	{
		WALAddArticleTableViewController *targetViewController = ((WALAddArticleTableViewController*)[segue.destinationViewController viewControllers][0]);
		targetViewController.delegate = self;
	}
}

#pragma mark - Callback Delegates

- (void)callbackFromSettingsController:(WALSettingsTableViewController *)settingsTableViewController withSettings:(WALSettings*)settings
{
	if (settings)
	{
		self.settings = settings;
		[settings saveSettings];
		[self updateArticles];
	}
	[self.navigationController dismissViewControllerAnimated:true completion:nil];
}

- (void)callbackFromAddArticleController:(WALAddArticleTableViewController *)addArticleController withURL:(NSURL *)url
{
	[self.navigationController dismissViewControllerAnimated:true completion:nil];	
}

#pragma mark - Error Handling

- (void) informUserConnectionError:(NSError*) error
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
														message:error.localizedDescription
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles: nil];
	[alertView show];
}

- (void) informUserWrongServerAddress
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
														message:NSLocalizedString(@"Could not connect to server. Maybe wrong URL?", @"error description: HTTP Status Code not 2xx")
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles: nil];
	[alertView show];
}

- (void) informUserWrongAuthentication
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
														message:NSLocalizedString(@"Could load feed. Maybe wrong user credentials?", @"error description: response is not a rss feed")
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles: nil];
	[alertView show];
}

- (void) informUserNoArticlesInFeed
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
														message:NSLocalizedString(@"No unread article in Feed. Get started by adding links to your wallabag.", @"error description: No article in home-feed")
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles: nil];
	[alertView show];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	NSLog(@"Parsing Error: %@", parseError.description);
	[self afterParsingComplete];
}

#pragma mark - Save Articles

- (void) saveArticles
{
	[NSKeyedArchiver archiveRootObject:self.articles toFile:[self pathToSavedArticles]];
}

- (void) loadArticles
{
	self.articles = [NSKeyedUnarchiver unarchiveObjectWithFile:[self pathToSavedArticles]];
}

- (NSURL*)applicationDataDirectory {
    NSFileManager* sharedFM = [NSFileManager defaultManager];
    NSArray* possibleURLs = [sharedFM URLsForDirectory:NSApplicationSupportDirectory
                                             inDomains:NSUserDomainMask];
    NSURL* appSupportDir = nil;
    NSURL* appDirectory = nil;
    
    if ([possibleURLs count] >= 1) {
        // Use the first directory (if multiple are returned)
        appSupportDir = [possibleURLs objectAtIndex:0];
    }
    
    // If a valid app support directory exists, add the
    // app's bundle ID to it to specify the final directory.
    if (appSupportDir) {
        NSString* appBundleID = [[NSBundle mainBundle] bundleIdentifier];
        appDirectory = [appSupportDir URLByAppendingPathComponent:appBundleID];
    }
    
    return appDirectory;
}

- (NSString*) pathToSavedArticles
{
	NSURL *applicationSupportURL = [self applicationDataDirectory];
    
    if (! [[NSFileManager defaultManager] fileExistsAtPath:[applicationSupportURL path]]){
		
        NSError *error = nil;
        
        [[NSFileManager defaultManager] createDirectoryAtPath:[applicationSupportURL path]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        
        if (error){
            NSLog(@"error creating app support dir: %@", error);
        }
        
    }
    NSString *path = [[applicationSupportURL path] stringByAppendingPathComponent:@"savedArticles.plist"];
    
    return path;
}

@end
