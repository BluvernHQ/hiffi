/// Stable analytics identifiers aligned with hiffi_web Activity Logs.
///
/// UI interactions → [`AnalyticsEvents.click`] + [element_ui_name].
/// Video opens → [`AnalyticsEvents.openedVideo`] + open-source tag.
/// Funnel steps → `conversion_*` events.
abstract final class AnalyticsEvents {
  static const click = r'$click';
  static const pageview = r'$pageview';
  static const openedVideo = 'opened-video';

  static const conversionPlayStarted = 'conversion_play_started';
  static const conversionNextClicked = 'conversion_next_clicked';
  static const conversionLikeSuccess = 'conversion_like_success';
  static const conversionUnlikeSuccess = 'conversion_unlike_success';
  static const conversionDislikeSuccess = 'conversion_dislike_success';
  static const conversionSignupCompleted = 'conversion_signup_completed';
  static const conversionAuthPromptShown = 'conversion_auth_prompt_shown';
  static const conversionAuthPromptDismissed = 'conversion_auth_prompt_dismissed';
}

/// `element_ui_name` / `data-analytics-name` values from the web catalog.
abstract final class AnalyticsTags {
  // Auth — login
  static const loginSkipButton = 'login-skip-button';
  static const loginTogglePasswordVisibilityButton =
      'login-toggle-password-visibility-button';
  static const loginSubmitButton = 'login-submit-button';

  // Auth — signup
  static const signupSkipButton = 'signup-skip-button';
  static const signupTogglePasswordVisibilityButton =
      'signup-toggle-password-visibility-button';
  static const signupCreateAccountButton = 'signup-create-account-button';
  static const signupVerifyOtpButton = 'signup-verify-otp-button';
  static const signupResendOtpButton = 'signup-resend-otp-button';
  static const signupBackToRegistrationButton =
      'signup-back-to-registration-button';

  // Navigation — app bar & sidebar (web uses underscores in sidebar)
  static const appbarLogo = 'appbar-logo';
  static const navbarOpenSearchButton = 'navbar-open-search-button';
  static const navbarOpenSearchButtonMobile = 'navbar-open-search-button-mobile';
  static const navbarOpenHiffiStudioButton = 'navbar-open-hiffi-studio-button';
  static const navbarOpenBecomeCreatorButton =
      'navbar-open-become-creator-button';
  static const navbarProfileLink = 'navbar-profile-link';
  static const navbarUserMenuHiffiStudioLink =
      'navbar-user-menu-hiffi-studio-link';
  static const navbarUserMenuBecomeCreatorLink =
      'navbar-user-menu-become-creator-link';
  static const navbarMyReportsLink = 'navbar-my-reports-link';
  static const navbarLoginButton = 'navbar-login-button';
  static const navbarSignupButton = 'navbar-signup-button';
  static const navbarLogoutConfirmButton = 'navbar-logout-confirm-button';
  static const sidebarHomeButton = 'sidebar_home_button';
  static const sidebarHistoryLink = 'sidebar_history_link';
  static const sidebarLikedVideosLink = 'sidebar_liked_videos_link';
  static const sidebarPlaylistsLink = 'sidebar_playlists_link';
  static const sidebarFollowingLink = 'sidebar_following_link';

  // Search overlay
  static const searchOverlayRecentSearchButton =
      'search-overlay-recent-search-button';
  static const searchOverlayTrendingSearchButton =
      'search-overlay-trending-search-button';
  static const searchOverlayUserResultLink = 'search-overlay-user-result-link';
  static const searchOverlayProcessingVideoResultButton =
      'search-overlay-processing-video-result-button';
  static const searchOverlayVideoResultLink = 'search-overlay-video-result-link';
  static const searchOverlayViewAllResultsButton =
      'search-overlay-view-all-results-button';

  // Video open sources
  static const openedVideo = 'opened-video';
  static const openedVideoFromHome = 'opened-video-from-home';
  static const openedVideoFromSearch = 'opened-video-from-search';
  static const openedVideoFromMood = 'opened-video-from-mood';
  static const openedVideoFromPlaylist = 'opened-video-from-playlist';
  static const openedVideoFromRecommended = 'opened-video-from-recommended';
  static const openedVideoFromLiked = 'opened-video-from-liked';
  static const openedVideoFromProfile = 'opened-video-from-profile';
  static const openedVideoFromHistory = 'opened-video-from-history';

  // Watch page & player
  static const watchLikeVideo = 'watch-like-video';
  static const watchUnlikeVideo = 'watch-unlike-video';
  static const watchSaveToPlaylist = 'watch-save-to-playlist';
  static const watchMoreActions = 'watch-more-actions';
  static const sharedVideo = 'shared-video';
  static const reportVideo = 'report-video';
  static const followedCreator = 'followed_creator';
  static const unfollowedCreator = 'unfollowed_creator';
  static const openedComments = 'opened-comments';
  static const playedVideo = 'played-video';
  static const pausedVideo = 'paused-video';
  static const playerPrevious = 'player-previous';
  static const playerNextRecommended = 'player-next-recommended';
  static const playerSeekBackward = 'player-seek-backward';
  static const playerSeekForward = 'player-seek-forward';
  static const mutedVideo = 'muted_video';
  static const unmutedVideo = 'unmuted_video';
  static const enteredFullscreen = 'entered_fullscreen';
  static const exitedFullscreen = 'exited_fullscreen';
  static const openedQualitySettings = 'opened-quality-settings';
  static const playlistQueueClick = 'playlist-queue-click';
  static const upNextSidebarClick = 'up-next-sidebar-click';
  static const upNextOverlayPlay = 'up-next-overlay-play';
  static const upNextOverlayCancel = 'up-next-overlay-cancel';
  static const globalPlayerExpandButton = 'global-player-expand-button';
  static const playerNextPlaylist = 'player-next-playlist';

  // Legacy engagement aliases (still recognized in Activity Logs)
  static const liked = 'liked';
  static const unliked = 'unliked';
  static const addedToPlaylist = 'added-to-playlist';
  static const videoCardAddToPlaylistButton = 'video-card-add-to-playlist-button';
  static const videoCardShare = 'video-card-share';

  // Comments & guest prompts
  static const guestCommentSignupLink = 'guest-comment-signup-link';
  static const guestCommentLoginLink = 'guest-comment-login-link';
  static const reportComment = 'report-comment';
  static const videoCommentSubmitButton = 'video-comment-submit-button';
  static const videoCommentLoadMoreButton = 'video-comment-load-more-button';
  static const videoCommentReplyToggleButton =
      'video-comment-reply-toggle-button';
  static const videoCommentReplySubmitButton =
      'video-comment-reply-submit-button';
  static const videoCommentReplyCancelButton =
      'video-comment-reply-cancel-button';
  static const videoCommentShowRepliesButton =
      'video-comment-show-replies-button';
  static const videoCommentHideRepliesButton =
      'video-comment-hide-replies-button';
  static const videoCommentDeletePromptButton =
      'video-comment-delete-prompt-button';
  static const videoCommentDeleteConfirmButton =
      'video-comment-delete-confirm-button';

  // Reports submitted
  static const reportProfile = 'report-profile';
  static String reportSubmitted(String type) => 'report-$type-submitted';

  // Upload & creator studio
  static const uploadCustomThumbnailButton = 'upload-custom-thumbnail-button';
  static const uploadRemoveThumbnailButton = 'upload-remove-thumbnail-button';
  static const uploadCancelDraftButton = 'upload-cancel-draft-button';
  static const uploadSubmitVideoButton = 'upload-submit-video-button';
  static const uploadSelectFilesButton = 'upload-select-files-button';
  static const uploadProgressWatchVideoButton =
      'upload-progress-watch-video-button';
  static const uploadSuccessWatchVideoButton =
      'upload-success-watch-video-button';
  static const uploadAnotherVideoButton = 'upload-another-video-button';
  static const creatorBecomeCreatorButton = 'creator-become-creator-button';
  static const creatorApplySignIn = 'creator-apply-sign-in';
  static const creatorApplySignUp = 'creator-apply-sign-up';
  static const creatorStudioUploadNewVideoButton =
      'creator-studio-upload-new-video-button';
  static const creatorStudioStartMigrationButton =
      'creator-studio-start-migration-button';
  static const creatorStudioStartMigrationSubmitButton =
      'creator-studio-start-migration-submit-button';
  static const creatorStudioManageProfileButton =
      'creator-studio-manage-profile-button';

  // Share sheet
  static const shareVideoCopyLinkButton = 'share-video-copy-link-button';
  static const shareVideoNativeShareButton = 'share-video-native-share-button';

  // Mood mix
  static const moodMixFullFeed = 'mood-mix-full-feed';
  static const moodMixOpenPicker = 'mood-mix-open-picker';
  static const moodMixDismissPicker = 'mood-mix-dismiss-picker';
  static const moodMixSwitchVibe = 'mood-mix-switch-vibe';
  static String moodMixSelect(String slug) => 'mood-mix-select-$slug';
  static String moodMixRun(String slug) => 'mood-mix-run-$slug';

  /// Dynamic profile view tag, e.g. `viewed-profile-of-jaxson-kaine`.
  static String viewedProfileOf(String username) =>
      'viewed-profile-of-${username.toLowerCase()}';
}
