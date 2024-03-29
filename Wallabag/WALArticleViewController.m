//
//  WALDetailViewController.m
//  Wallabag
//
//  Created by Kevin Meyer on 19.02.14.
//  Copyright (c) 2014 Wallabag. All rights reserved.
//

#import "WALArticleViewController.h"
#import "WALArticle.h"
#import "WALBrowserViewController.h"
#import "WALNavigationController.h"
#import "WALTheme.h"
#import "WALThemeOrganizer.h"

@interface WALArticleViewController ()
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *markAsReadButton;
- (IBAction)markAsReadPushed:(id)sender;
- (IBAction)changeThemePushed:(id)sender;
- (IBAction)sharePushed:(id)sender;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *changeThemePushed;
@property (strong) WALArticle *article;
@property (strong) NSURL *externalURL;
@property BOOL nextViewIsBrowser;
@end

@implementation WALArticleViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.webView.delegate = self;
	[self configureView];
	[[WALThemeOrganizer sharedThemeOrganizer] subscribeToThemeChanges:self];
}

- (void)viewWillAppear:(BOOL)animated
{
	self.nextViewIsBrowser = NO;
	if (self.navigationController.isToolbarHidden)
		[self.navigationController setToolbarHidden:NO animated:animated];
	
	[super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	if (!self.nextViewIsBrowser)
		[self.navigationController setToolbarHidden:YES animated:animated];
	
	[super viewWillDisappear:animated];
}

- (void) updateButtons
{
	if (self.article.archive)
		self.markAsReadButton.title = @"Mark as unread";
	else
		self.markAsReadButton.title = @"Mark as read";
}

#pragma mark - Managing the detail item

- (void) setDetailArticle:(WALArticle*) article
{
	self.article = article;
	[self updateButtons];
	self.title = self.article.title;
}

- (void) configureView
{
	NSString *originalTitle = NSLocalizedString(@"Open Original:", nil);

	WALTheme *currentTheme = [[WALThemeOrganizer sharedThemeOrganizer] getCurrentTheme];
	NSURL *mainCSSFile = [currentTheme getPathToMainCSSFile];
	NSURL *extraCSSFile = [currentTheme getPathtoExtraCSSFile];
	
	NSString *htmlFormat = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"article" ofType:@"html"] encoding:NSUTF8StringEncoding error:nil];
	NSString *htmlToDisplay = [NSString stringWithFormat:htmlFormat, mainCSSFile, extraCSSFile, self.article.title, originalTitle, self.article.link, self.article.link.host,  [self.article getContent]];
	
	[self.webView loadHTMLString:htmlToDisplay baseURL:nil];
}

#pragma mark - WebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	NSLog(@"WebView Error: %@\nWebView Error: %@", error.description, error.localizedFailureReason);
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{	
	if (navigationType != UIWebViewNavigationTypeOther)
	{
		//[[UIApplication sharedApplication] openURL:request.URL];
		self.externalURL = request.URL;
		[self performSegueWithIdentifier:@"PushToBrowser" sender:nil];
		return FALSE;
	}
	
	return true;
}

#pragma mark - Theming

- (void)themeOrganizer:(WALThemeOrganizer *)organizer setNewTheme:(WALTheme *)theme
{
	[self updateWithTheme:theme];
}

- (void) updateWithTheme:(WALTheme*) theme
{
	NSURL *mainCSSFile = [theme getPathToMainCSSFile];
	NSURL *extraCSSFile = [theme getPathtoExtraCSSFile];
	
	NSString *javaScriptToChangeTheme = [NSString stringWithFormat:@"document.getElementById('main-theme').href='%@';\ndocument.getElementById('extra-theme').href='%@';", mainCSSFile, extraCSSFile];
	[self.webView stringByEvaluatingJavaScriptFromString:javaScriptToChangeTheme];
}

#pragma mark - Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([segue.identifier isEqualToString:@"PushToBrowser"])
	{
		self.nextViewIsBrowser = YES;
		[((WALBrowserViewController*)segue.destinationViewController) setStartURL:self.externalURL];
	}
}

- (IBAction)markAsReadPushed:(id)sender
{
	//! @todo inform user (one time) that this won't affect his online wallabag.
	
	self.article.archive = !self.article.archive;
	[self updateButtons];
}

- (IBAction)changeThemePushed:(id)sender
{
	[[WALThemeOrganizer sharedThemeOrganizer] changeTheme];
}

- (IBAction)sharePushed:(id)sender
{
	NSArray* dataToShare = @[self.title, self.article.link];
	
	//! @todo add more custom activities
	
	UIActivityViewController* activityViewController =
	[[UIActivityViewController alloc] initWithActivityItems:dataToShare applicationActivities:nil];
	[self presentViewController:activityViewController animated:YES completion:^{}];
}
@end
