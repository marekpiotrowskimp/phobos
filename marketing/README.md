# Marketing materials — PHOBOS Survivor 0.1.0 (iOS)

| File | Use |
|------|-----|
| `linkedin_post.md` | LinkedIn feed post (main and short version, plus first comment) |
| `linkedin_article.md` | LinkedIn article (Write article → paste) |
| `article/article.html` | The article ready to copy, with images in place (open in a browser) |
| `article/00_cover.png` … `03_scores.png` | Cover and inline images for the article |
| `images/linkedin_post_1080x1350.png` | Image for the post (4:5 portrait, takes the most space in the feed) |
| `images/linkedin_article_cover_1920x1080.png` | Article cover image |
| `make_graphics.sh` | Regenerates all images from `../ports/ios/release/screenshots/EN/iphone-6.3/` (needs ImageMagick) |

## Before publishing

- [ ] App Review approved and the app is live
- [ ] Replace `<APP_STORE_LINK>` (in `linkedin_article.md`, `linkedin_post.md` and `article/article.html`) with the App Store link: App Store Connect → App Information → **View on App Store**
- [x] GitHub repo is public: https://github.com/marekpiotrowskimp/phobos
- [ ] After publishing the article, put its link in the post's first comment (`<ARTICLE_LINK>`)
- [ ] Optional: shorten or remove the "Behind the game" section if you want a purely product-focused article

## Suggested order

1. Publish the article first.
2. Two or three days later, publish the post with the image and links to the App Store and the article in the first comment.
