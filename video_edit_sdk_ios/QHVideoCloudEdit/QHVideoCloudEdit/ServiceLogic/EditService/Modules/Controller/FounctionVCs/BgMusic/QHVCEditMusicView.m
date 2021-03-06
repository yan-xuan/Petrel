//
//  QHVCEditMusicView.m
//  QHVideoCloudEdit
//
//  Created by liyue-g on 2018/11/26.
//  Copyright © 2018 yangkui. All rights reserved.
//

#import "QHVCEditMusicView.h"
#import "UIView+Toast.h"
#import "QHVCEditPrefs.h"
#import "QHVCEditFrameView.h"
#import "QHVCEditMusicListView.h"
#import "QHVCEditMediaEditor.h"
#import "QHVCEditMediaEditorConfig.h"
#import "QHVCEditPlayerBaseVC.h"

@interface QHVCEditMusicView ()

@property (weak, nonatomic) IBOutlet UIView *timelineContentView;
@property (weak, nonatomic) IBOutlet UIView *musicContentView;
@property (weak, nonatomic) IBOutlet UIButton *musicListButton;
@property (weak, nonatomic) IBOutlet UISlider *musicVolumeSlider;
@property (weak, nonatomic) IBOutlet UISwitch *musicFIFOSwitch;

@property (nonatomic, retain) QHVCEditFrameView* timelineView;
@property (nonatomic, retain) QHVCEditTrackClipItem* currentClipItem;

@end

@implementation QHVCEditMusicView

#pragma mark - Life Circle Methods

- (void)prepareSubviews
{
    [super prepareSubviews];
    
    self.timelineView = [[NSBundle mainBundle] loadNibNamed:@"QHVCEditFrameView" owner:self options:nil][0];
    [self.timelineView setPlayerBaseVC:self.playerBaseVC];
    [self.timelineContentView addSubview:self.timelineView];
    [self.timelineContentView setHidden:NO];
    [self.musicContentView setHidden:YES];
    SAFE_BLOCK(self.pausePlayerBlock);
    SAFE_BLOCK(self.seekPlayerBlock, YES, 0);
    SAFE_BLOCK(self.hidePlayButtonBolck, YES);
    
    WEAK_SELF
    [self.timelineView setPlayAction:^{
        STRONG_SELF
        SAFE_BLOCK(self.playPlayerBlock);
    }];
    
    [self.timelineView setPauseAction:^{
        STRONG_SELF
        SAFE_BLOCK(self.pausePlayerBlock);
    }];
    
    [self.timelineView setSeekAction:^(BOOL forceRefresh, NSInteger seekToTime)
    {
        STRONG_SELF
        SAFE_BLOCK(self.seekPlayerBlock, forceRefresh, seekToTime);
    }];
    
    [self.timelineView setAddAction:^{
        STRONG_SELF
        [self showMusicView];
    }];
}

- (void)confirmAction
{
    SAFE_BLOCK(self.hidePlayButtonBolck, NO);
    SAFE_BLOCK(self.confirmBlock, self);
}

- (void)showMusicView
{
    if ([[QHVCEditMediaEditorConfig sharedInstance] musicClipItem])
    {
        self.currentClipItem = [[QHVCEditMediaEditorConfig sharedInstance] musicClipItem];
        
        NSString* musicName = [self.currentClipItem.filePath lastPathComponent];
        NSInteger volume = [[QHVCEditMediaEditorConfig sharedInstance] musicVolume];
        BOOL hasFIFO = [[QHVCEditMediaEditorConfig sharedInstance] musicHasFIFO];
        [self.musicListButton setTitle:musicName forState:UIControlStateNormal];
        [self.musicVolumeSlider setValue:volume];
        [self.musicFIFOSwitch setOn:hasFIFO];
    }
    
    [self setConfirmButtionState:YES];
    [self.timelineContentView setHidden:YES];
    [self.musicContentView setHidden:NO];
}

- (void)hideMusicView
{
    [self setConfirmButtionState:NO];
    [self.timelineContentView setHidden:NO];
    [self.musicContentView setHidden:YES];
}

#pragma mark - Event Response Methods

- (IBAction)clickedEditMusicCompleteBtn:(id)sender
{
    [self hideMusicView];
}

- (IBAction)clickedMusicListBtn:(UIButton *)sender
{
    QHVCEditMusicListView* view = [[NSBundle mainBundle] loadNibNamed:[[QHVCEditMusicListView class] description] owner:self options:nil][0];
    [view setFrame:CGRectMake(0, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame))];
    [self.musicContentView addSubview:view];
    
    WEAK_SELF
    [view setCompleteAction:^(NSString * _Nonnull fileName)
     {
         STRONG_SELF
         [self updateMusic:fileName];
    }];
}

- (IBAction)onMusicVolumeChanged:(UISlider *)sender
{
    if (!self.currentClipItem)
    {
        return;
    }
    
    [[QHVCEditMediaEditor sharedInstance] setMainAduioTrackVolume:sender.value];
    [[QHVCEditMediaEditorConfig sharedInstance] setMusicVolume:sender.value];
    
    BOOL isPlaying = [self.playerBaseVC isPlaying];
    SAFE_BLOCK(self.resetPlayerBlock);
    if (isPlaying)
    {
        SAFE_BLOCK(self.playPlayerBlock);
    }
}

- (IBAction)onMusicFIFOValueChanged:(UISwitch *)sender
{
    if (!self.currentClipItem)
    {
        return;
    }
    
    if (sender.isOn)
    {
        [self addFIFO];
    }
    else
    {
        [self deleteFIFO];
    }
    
    [[QHVCEditMediaEditorConfig sharedInstance] setMusicHasFIFO:sender.isOn];
    
    BOOL isPlaying = [self.playerBaseVC isPlaying];
    SAFE_BLOCK(self.resetPlayerBlock);
    if (isPlaying)
    {
        SAFE_BLOCK(self.playPlayerBlock);
    }
}

#pragma mark - Editor Methods

- (void)addMusic:(NSString *)fileName
{
    QHVCEditTrackClipItem* item = [self createClipItem:fileName];
    if (!item)
    {
        return;
    }
    
    [[QHVCEditMediaEditor sharedInstance] createMainAudioTrack];
    [[QHVCEditMediaEditor sharedInstance] mainAudioTrackAppendClip:item];
    [[QHVCEditMediaEditorConfig sharedInstance] setMusicClipItem:item];
    self.currentClipItem = item;
}

- (void)updateMusic:(NSString *)fileName
{
    [self.musicListButton setTitle:fileName forState:UIControlStateNormal];
    if ([fileName isEqualToString:@"--"])
    {
        [self deleteMusic:fileName];
    }
    else
    {
        if (self.currentClipItem)
        {
            //update
            [[QHVCEditMediaEditor sharedInstance] mainAudioTrackDeleteClip:self.currentClipItem];
            QHVCEditTrackClipItem* item = [self createClipItem:fileName];
            [[QHVCEditMediaEditor sharedInstance] mainAudioTrackAppendClip:item];
            [[QHVCEditMediaEditorConfig sharedInstance] setMusicClipItem:item];
            self.currentClipItem = item;
        }
        else
        {
            //add
            [self addMusic:fileName];
        }
    }
    
    BOOL isPlaying = [self.playerBaseVC isPlaying];
    SAFE_BLOCK(self.resetPlayerBlock);
    if (isPlaying)
    {
        SAFE_BLOCK(self.playPlayerBlock);
    }
}

- (void)deleteMusic:(NSString *)fileName
{
    [[QHVCEditMediaEditor sharedInstance] deleteMainAudioTrack];
    [[QHVCEditMediaEditorConfig sharedInstance] setMusicClipItem:nil];
    self.currentClipItem = nil;
}

- (QHVCEditTrackClipItem *)createClipItem:(NSString *)fileName
{
    NSString* filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    QHVCEditFileInfo* fileInfo = [QHVCEditTools getFileInfo:filePath];
    if (!fileInfo)
    {
        return nil;
    }
    
    NSInteger duration = MIN([[QHVCEditMediaEditor sharedInstance] getTimelineDuration], fileInfo.durationMs);
    QHVCEditTrackClipItem* item = [[QHVCEditTrackClipItem alloc] init];
    item.filePath = filePath;
    item.startMs = 0;
    item.endMs = duration;
    item.clipType = QHVCEditTrackClipTypeAudio;
    return item;
}

- (void)addFIFO
{
    QHVCEditMediaEditor* mediaEditor = [QHVCEditMediaEditor sharedInstance];
    QHVCEditAudioTransferEffect *audioTransferFadeIn = [[QHVCEditAudioTransferEffect alloc] initEffectWithTimeline:[mediaEditor getTimeline]];
    audioTransferFadeIn.startTime = 0;
    audioTransferFadeIn.endTime = self.currentClipItem.clip.duration / 2.0;
    audioTransferFadeIn.transferType = QHVCEditAudioTransferTypeFadeIn;
    audioTransferFadeIn.gainMin = 0;
    audioTransferFadeIn.gainMax = 100;
    audioTransferFadeIn.transferCurveType = QHVCEditAudioTransferCurveTypeLog;
    [self.currentClipItem.clip addEffect:audioTransferFadeIn];
    
    QHVCEditAudioTransferEffect *audioTransferFadeOut = [[QHVCEditAudioTransferEffect alloc] initEffectWithTimeline:[mediaEditor getTimeline]];
    audioTransferFadeOut.startTime = self.currentClipItem.clip.duration / 2.0;
    audioTransferFadeOut.endTime = self.currentClipItem.clip.duration;
    audioTransferFadeOut.transferType = QHVCEditAudioTransferTypeFadeOut;
    audioTransferFadeOut.gainMin = 0;
    audioTransferFadeOut.gainMax = 100;
    audioTransferFadeOut.transferCurveType = QHVCEditAudioTransferCurveTypeLog;
    [self.currentClipItem.clip addEffect:audioTransferFadeOut];
    
    BOOL isPlaying = [self.playerBaseVC isPlaying];
    SAFE_BLOCK(self.resetPlayerBlock);
    if (isPlaying)
    {
        SAFE_BLOCK(self.playPlayerBlock);
    }
}

- (void)deleteFIFO
{
     NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings)
     {
         QHVCEditEffect *effect = (QHVCEditEffect *)evaluatedObject;
         if (effect.effectType == QHVCEditEffectTypeAudio)
         {
             return YES;
         }
         return NO;
     }];
    
     NSArray *clipEffects = [self.currentClipItem.clip getEffects];
     NSArray *effects = [clipEffects filteredArrayUsingPredicate:predicate];
     [effects enumerateObjectsUsingBlock:^(QHVCEditEffect *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
      {
          [self.currentClipItem.clip deleteEffectById:obj.effectId];
      }];
}

@end
