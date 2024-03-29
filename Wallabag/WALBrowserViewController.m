//
//  WALBrowserViewController.m
//  Wallabag
//
//  Created by Kevin Meyer on 24.02.14.
//  Copyright (c) 2014 Wallabag. All rights reserved.
//

#import "WALBrowserViewController.h"

@interface WALBrowserViewController ()
@property (strong) NSURL *initialUrl;
@property (weak, nonatomic) IBOutlet UIWebView *webView;

- (IBAction)refreshToolbarButtonPushed:(id)sender;
- (IBAction)shareToolbarButtonPushed:(id)sender;
- (IBAction)backToolbarButtonPushed:(id)sender;
- (IBAction)forwardToolbarButtonPushed:(id)sender;


@property (strong, nonatomic) IBOutlet UIBarButtonItem *backToolBarButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *forwardToolbarButton;
@end

@implementation WALBrowserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.webView.delegate = self;
	
	[self.webView loadRequest:[NSURLRequest requestWithURL:self.initialUrl]];
	self.title = [self.initialUrl absoluteString];
	[self updateToolbarButtons];
}

- (void)setStartURL:(NSURL*) startURL
{
	self.initialUrl = startURL;
}

- (void)viewWillAppear:(BOOL)animated
{
	if (self.navigationController.isToolbarHidden)
		[self.navigationController setToolbarHidden:NO animated:animated];
	
	[super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
//	[self.navigationController setToolbarHidden:YES animated:animated];
	[super viewWillDisappear:animated];
}

#pragma mark - ToolbarButton Actions

- (IBAction)refreshToolbarButtonPushed:(id)sender
{
	[self.webView reload];
}

- (IBAction)shareToolbarButtonPushed:(id)sender
{
	///! @todo implement and extend functions
	
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:self.webView.request.mainDocumentURL.absoluteString
															 delegate:self
													cancelButtonTitle:NSLocalizedString(@"cancel", nil)
											   destructiveButtonTitle:nil
													otherButtonTitles:NSLocalizedString(@"Open in Safari", nil), NSLocalizedString(@"Share link", nil), nil];
	actionSheet.tag = 1;
	
	[actionSheet showFromToolbar:self.navigationController.toolbar];
}

- (IBAction)backToolbarButtonPushed:(id)sender
{
	[self.webView goBack];
}

- (IBAction)forwardToolbarButtonPushed:(id)sender
{
	[self.webView goForward];
}

- (void) updateToolbarButtons
{
	self.backToolBarButton.enabled = [self.webView canGoBack];
	self.forwardToolbarButton.enabled = [self.webView canGoForward];
}

#pragma mark - WebView Delegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	if (navigationType != UIWebViewNavigationTypeOther)
	{
		self.title = self.webView.request.mainDocumentURL.absoluteString;
	}
	
	return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	self.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
	[self updateToolbarButtons];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateToolbarButtons];
	
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
														message:error.localizedDescription
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles: nil];
	[alertView show];

}

#pragma mark - ActionSheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (actionSheet.tag == 1)
	{
		//NSLog(@"Pressed Button: %ld", (long)buttonIndex);
		
		// Open in Safari
		if (buttonIndex == 0)
		{
			[[UIApplication sharedApplication] openURL:self.webView.request.mainDocumentURL];
		}
		// Share link
		else if (buttonIndex == 1)
		{
			NSArray* dataToShare = @[self.title, self.webView.request.mainDocumentURL];
			
			//! @todo add more custom activities
			
			UIActivityViewController* activityViewController =
			[[UIActivityViewController alloc] initWithActivityItems:dataToShare applicationActivities:nil];
			[self presentViewController:activityViewController animated:YES completion:^{}];
		}
	}
}


@end
