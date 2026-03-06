# Analytics & Optimization

## Platform Analytics APIs

### Instagram Insights API

**Endpoint:** `GET /{media-id}/insights`

**Available Metrics:**
- `impressions` — total times the content was displayed
- `reach` — unique accounts that saw the content
- `engagement` — total interactions (likes + comments + saves + shares)
- `saved` — number of saves (strongest ranking signal)
- `shares` — number of shares to DMs and stories
- `video_views` — views for video content (3+ seconds)
- `plays` — total plays for reels (includes replays)

**Account-Level Metrics:**
- `follower_count` — total followers
- `follower_demographics` — age, gender, location breakdowns
- `online_followers` — when followers are most active (by hour and day)
- `profile_views` — profile visits in time period
- `website_clicks` — link clicks from profile

**Requirements:**
- Instagram Business or Creator account
- Meta Business Suite access token
- Facebook Graph API v18.0+
- Token permissions: `instagram_manage_insights`, `pages_show_list`

**Rate Limits:** 200 calls per hour per user token

---

### TikTok Analytics API

**Endpoint:** `GET /v2/video/query/`

**Available Metrics:**
- `views` — total video views
- `likes` — total likes
- `comments` — total comments
- `shares` — total shares
- `avg_watch_time` — average seconds watched per view
- `total_watch_time` — cumulative watch time
- `traffic_source` — where views came from (For You, Following, Profile, Search, Sound)
- `audience_territories` — viewer locations

**Creator Tools API:**
- Detailed analytics for creator accounts
- Content performance over 7/28/60 day windows
- Follower activity patterns
- Content category performance breakdown

**Authentication:** OAuth 2.0 with `video.list` and `video.insights` scopes

**Rate Limits:** 600 requests per minute per app

---

### YouTube Analytics API

**Endpoint:** `GET https://youtubeanalytics.googleapis.com/v2/reports`

**Core Metrics:**
- `views` — total video views
- `watchTimeMinutes` — total watch time in minutes
- `averageViewDuration` — average seconds per view
- `averageViewPercentage` — average percentage of video watched
- `likes` — total likes
- `dislikes` — total dislikes
- `comments` — total comments
- `subscribersGained` — new subscribers from content
- `subscribersLost` — unsubscribes from content
- `estimatedRevenue` — estimated ad revenue (monetized channels)
- `ctr` — click-through rate on impressions

**Dimensions for Breakdown:**
- `day` — daily breakdown
- `video` — per-video metrics
- `country` — geographic breakdown
- `ageGroup` — audience age segments
- `gender` — audience gender split
- `deviceType` — mobile, desktop, tablet, TV
- `trafficSource` — search, suggested, browse, external, etc.

**Real-Time Data:** Available within ~2 hours of events

**Authentication:** OAuth 2.0 with `yt-analytics.readonly` scope

---

### X/Twitter Analytics

**Tweet Metrics (API v2):**
- `impression_count` — times the tweet was seen
- `like_count` — total likes
- `retweet_count` — total retweets (including quote tweets)
- `reply_count` — total replies
- `url_link_clicks` — clicks on links in the tweet
- `user_profile_clicks` — clicks to the author profile
- `bookmark_count` — times bookmarked

**Account Metrics:**
- Follower growth over time
- Profile visits
- Mention count
- Top tweet by engagement

**Authentication:** OAuth 2.0 Bearer token or OAuth 1.0a user context

**Rate Limits:** Vary by API tier (Basic: 10k tweets/month read, Pro: 1M tweets/month)

---

## KPI Definitions

### Reach Metrics
- **Reach** — unique accounts that saw content. Primary measure of content distribution. Higher reach = more discovery.
- **Impressions** — total times content was displayed, including repeat views by same user. Impressions >= Reach always.

### Engagement Metrics
- **Engagement Rate** — `(likes + comments + shares + saves) / reach x 100`. Industry benchmarks: Instagram 1-5%, TikTok 3-9%, YouTube 2-6%.
- **Click-Through Rate (CTR)** — `clicks / impressions x 100`. Measures how compelling the content is at driving action. Good CTR: >2% for organic, >1% for ads.
- **Save Rate** — `saves / reach x 100`. Strongest signal on Instagram; indicates high-value content users want to revisit. Target: >2%.
- **Share Rate** — `shares / reach x 100`. Strongest signal on TikTok; indicates content worth spreading. Target: >1%.
- **Comment Rate** — `comments / reach x 100`. Indicates conversation-starting content. Quality matters more than quantity.

### Video Metrics
- **Watch Time** — total minutes viewed across all viewers. YouTube's primary ranking factor.
- **Average View Duration** — `total watch time / total views`. Measures content retention. Target: >50% of video length.
- **Completion Rate** — percentage of viewers who watched to the end. Critical for short-form (target >60%).

### Growth Metrics
- **Follower Conversion** — `new followers / reach x 100`. Measures how well content converts viewers to followers. Target: >0.5%.
- **Viral Coefficient** — `shares per view x new views per share`. >1.0 means exponential growth.

---

## Content Performance Scoring

### Scoring Formula
```
Score = (engagement_rate x 0.3) + (reach_growth x 0.2) +
        (save_rate x 0.2) + (share_rate x 0.2) + (comment_quality x 0.1)
```

### Normalization
Each component is normalized to 0-100 scale before weighting:
- `engagement_rate`: 0% = 0, 10%+ = 100
- `reach_growth`: 0x average = 0, 5x average = 100
- `save_rate`: 0% = 0, 5%+ = 100
- `share_rate`: 0% = 0, 3%+ = 100
- `comment_quality`: automated sentiment score 0-100

### Grade Definitions
```
A+ (90-100): Viral potential — amplify immediately with paid boost, create
             variations, cross-post everywhere, study what made it work
A  (80-89):  Strong performer — create 2-3 variations with different hooks,
             repurpose for other platforms, add to "best of" collection
B  (70-79):  Good content — optimize caption/hashtags and repost at peak time,
             test different thumbnails, extract learnings
C  (60-69):  Average — analyze individual metrics to find weak points,
             A/B test improvements, consider different content angle
D  (below 60): Underperformer — archive the learnings (what didn't work and why),
               don't repeat the approach without significant changes
```

### Automated Grading Implementation
```
1. Collect metrics 48 hours after publishing (short-form) or 7 days (long-form)
2. Calculate each component score
3. Apply weights and sum
4. Assign grade
5. Update asset manifest with score and grade
6. Trigger appropriate action (amplify / optimize / archive)
```

---

## Trend Detection

### Engagement Spike Monitoring
- Track rolling 7-day average engagement rate per content type
- Alert when a post exceeds 2x the rolling average (potential viral content)
- Alert when engagement drops below 0.5x average (potential issue or shadow ban)
- Monitor velocity: rapid early engagement (first 1 hour) predicts virality

### Hashtag Performance Tracking
- Maintain a hashtag performance database
- Track reach and engagement per hashtag over time
- Identify hashtag fatigue (declining returns) — rotate every 2-4 weeks
- Discover trending hashtags in niche through competitor monitoring
- Optimal hashtag count: Instagram 5-10, TikTok 3-5, Twitter 1-2

### Content Type Analysis
- Monthly breakdown of performance by content type (reel, carousel, static, story)
- Identify which types are trending up or down
- Allocate production resources toward highest-performing types
- Test emerging formats early (new platform features get algorithmic boost)

### Seasonal Pattern Recognition
- Build a 12-month content calendar based on historical performance
- Identify recurring peaks: holidays, industry events, cultural moments
- Plan content production 2-4 weeks ahead of seasonal peaks
- Track year-over-year trends to predict future patterns

### Competitor Content Signals
- Monitor 5-10 competitor accounts for content strategy changes
- Track their highest-performing content types and themes
- Identify gaps: topics they don't cover well that you can own
- Note posting frequency and timing patterns

---

## Automated Reporting Template

```markdown
## Weekly Content Report — {date_range}

### Executive Summary
- Total posts published: {total_posts}
- Total reach: {total_reach} ({reach_change}% vs last week)
- Average engagement rate: {avg_engagement}% ({engagement_change}% vs last week)
- Best performer: {best_post_title} (reach: {best_reach}, engagement: {best_engagement}%)
- Worst performer: {worst_post_title} (reach: {worst_reach}, engagement: {worst_engagement}%)
- New followers gained: {new_followers} ({follower_change}% vs last week)

### Platform Breakdown
| Platform  | Posts | Reach     | Engagement | Best Post    | Grade |
|-----------|-------|-----------|------------|--------------|-------|
| Instagram | {x}   | {x}       | {x}%       | [{title}]({link}) | {grade} |
| TikTok    | {x}   | {x}       | {x}%       | [{title}]({link}) | {grade} |
| YouTube   | {x}   | {x}       | {x}%       | [{title}]({link}) | {grade} |
| Twitter   | {x}   | {x}       | {x}%       | [{title}]({link}) | {grade} |

### Content Type Performance
| Type      | Count | Avg Reach | Avg Engagement | Avg Score | Trend     |
|-----------|-------|-----------|----------------|-----------|-----------|
| Reels     | {x}   | {x}       | {x}%           | {x}       | {up/down} |
| Carousel  | {x}   | {x}       | {x}%           | {x}       | {up/down} |
| Static    | {x}   | {x}       | {x}%           | {x}       | {up/down} |
| Stories   | {x}   | {x}       | {x}%           | {x}       | {up/down} |
| Shorts    | {x}   | {x}       | {x}%           | {x}       | {up/down} |

### Top Performing Content (A/A+ Grade)
1. [{title}]({link}) — Score: {score}, Reach: {reach}, Engagement: {engagement}%
2. [{title}]({link}) — Score: {score}, Reach: {reach}, Engagement: {engagement}%
3. [{title}]({link}) — Score: {score}, Reach: {reach}, Engagement: {engagement}%

### Underperforming Content (D Grade) — Learnings
1. [{title}]({link}) — Score: {score}, Likely cause: {analysis}
2. [{title}]({link}) — Score: {score}, Likely cause: {analysis}

### Hashtag Performance
| Hashtag      | Uses | Avg Reach | Avg Engagement | Status      |
|--------------|------|-----------|----------------|-------------|
| #{tag}       | {x}  | {x}       | {x}%           | {trending/stable/declining} |

### Audience Growth
- Total followers: {total} (+{new} this week)
- Top growth platform: {platform} (+{count})
- Peak activity times: {times}
- Top audience locations: {locations}

### Recommendations
1. {data-driven recommendation based on top performers}
2. {trend to capitalize on based on spike detection}
3. {content type to increase/decrease based on performance data}
4. {hashtag strategy adjustment}
5. {posting schedule optimization based on audience activity}

### Next Week Plan
- Planned posts: {count}
- Content types: {breakdown}
- Key themes: {themes}
- A/B tests: {tests planned}
```

### Report Generation Cadence
- **Daily**: engagement spike alerts, viral content detection (automated)
- **Weekly**: full performance report (automated with manual insights)
- **Monthly**: trend analysis, strategy review, content calendar planning
- **Quarterly**: deep-dive analytics, ROI assessment, strategy pivot decisions

---

## Content Recycling Rules

### Repurpose Top Performers
- A/A+ grade content eligible for repurpose after 30 days
- Create variations: different hook, new caption, alternative thumbnail
- Transform format: reel to carousel, carousel to reel, long-form to clips
- Cross-post: adapt for other platforms with platform-specific optimizations

### Format Transformation Matrix
```
Long-form video (5+ min) →
  ├── 3-5 short-form clips (15-60s) for Reels/TikTok/Shorts
  ├── Quote graphics from key moments
  ├── Blog post or thread from transcript
  └── Audiogram for podcast-style sharing

Carousel →
  ├── Reel (animated slides with narration)
  ├── Individual slides as standalone posts
  ├── Thread (Twitter/X)
  └── Infographic (combined into single image)

Static post →
  ├── Story with engagement sticker
  ├── Carousel (expand into multi-slide)
  └── Video commentary overlay
```

### Evergreen Content Refresh
- Quarterly review of evergreen content library
- Update statistics, examples, and references
- Refresh visuals while keeping proven structure
- Re-publish with updated caption and hashtags
- Track performance delta vs original

### Archive and Learn from Underperformers
- Tag D-grade content with failure category:
  - `weak_hook` — didn't stop the scroll
  - `low_relevance` — audience didn't care about topic
  - `poor_timing` — posted at wrong time or during competing event
  - `weak_visual` — image/video quality issue
  - `wrong_format` — content type mismatch for platform
- Build a "what not to do" reference from patterns
- Review archive monthly for pattern changes (what failed 6 months ago might work now)
