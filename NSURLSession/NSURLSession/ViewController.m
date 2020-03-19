//  ViewController.m


#import "ViewController.h"
#import "SSZipArchive.h"
@interface ViewController () <NSURLSessionDelegate, NSURLSessionDownloadDelegate>

@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UIProgressView *progressView;
@property (strong, nonatomic) IBOutlet UIButton *cancelButton;
@property (strong, nonatomic) IBOutlet UIButton *resumeButton;
@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSURLSessionDownloadTask *downloadTask;
@property (strong, nonatomic) NSData *resumeData;

- (IBAction)cancel:(id)sender;
- (IBAction)resume:(id)sender;

@end

@implementation ViewController

#pragma mark View Life Cycle
- (void)viewDidLoad
{
    [super viewDidLoad];

    [self addObserver:self forKeyPath:@"resumeData" options:NSKeyValueObservingOptionNew context:NULL];
    [self addObserver:self forKeyPath:@"downloadTask" options:NSKeyValueObservingOptionNew context:NULL];
    
    self.cancelButton.hidden = YES;
    self.resumeButton.hidden = YES;
    
    self.downloadTask = [self.session downloadTaskWithURL:[NSURL URLWithString:@"https://down.hoyi52.com/test/static.zip"]];
    
    [self.downloadTask resume];
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"resumeData"];
    [self removeObserver:self forKeyPath:@"downloadTask"];
}

#pragma mark Getters & Setters
- (NSURLSession *)session
{
    if (! _session)
    {
        // backgroundSessionConfigurationWithIdentifier
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"hello"];
        
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
    }
    
    return _session;
}

- (void)setProgressView:(UIProgressView *)progressView
{
    if (_progressView != progressView)
    {
        _progressView = progressView;
        _progressView.progress = 0;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark IBAction
- (IBAction)cancel:(id)sender
{
    if (! self.downloadTask) return;
    
    [self.downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        if (resumeData)
        {
            [self setResumeData:resumeData];
            [self setDownloadTask:nil];
        }
    }];
}

- (IBAction)resume:(id)sender
{
    if (! self.resumeData) return;    
    self.downloadTask = [self.session downloadTaskWithResumeData:self.resumeData];    
    [self.downloadTask resume];   
    [self setResumeData:nil];
}

#pragma mark Session Download Delegate Method
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{   
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cacheDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"];
    NSString *fileName = [location lastPathComponent];
    NSString *cacheFile = [cacheDir stringByAppendingPathComponent:fileName];
    NSURL *cacheFileURL = [NSURL fileURLWithPath:cacheFile];
    
    NSError *error = nil;
    if ([fileManager moveItemAtURL:location
                             toURL:cacheFileURL
                             error:&error]) {

        self.progressView.hidden = YES;
        self.cancelButton.hidden = YES; 
        NSString *zipPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];                                     
        NSLog(@"unzipPath : %@", zipPath);
        BOOL success = [SSZipArchive unzipFileAtPath:cacheFileURL.path
                                       toDestination:zipPath];
        if (success) {
            NSLog(@"Success unzip");
        } else {
            NSLog(@"No success unzip");
        }

    } else {
        NSLog(@"error : %@", [error localizedDescription]);
    }
    [session finishTasksAndInvalidate];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    NSLog(@"%d %s",__LINE__ ,__PRETTY_FUNCTION__);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    //...
}

#pragma mark Key Value Observing
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"resumeData"])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.resumeButton.hidden = (self.resumeData == nil);
        });
    }
    else if ([keyPath isEqualToString:@"downloadTask"])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cancelButton.hidden = (self.downloadTask == nil);
        });
    }
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end
