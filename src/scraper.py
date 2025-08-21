#!/usr/bin/env python3
"""
Google News Scraper for Medicaid Policy News
Scrapes the top 5 articles from Google News search results using Playwright
"""

from playwright.sync_api import sync_playwright, Browser, Page
import time
import re
from urllib.parse import urljoin, urlparse
from typing import List, Dict, Optional
import logging

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class GoogleNewsScraper:
    def __init__(self):
        self.playwright = None
        self.browser = None
        self.page = None
    
    def __enter__(self):
        """Context manager entry"""
        self.start_browser()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close_browser()
    
    def start_browser(self):
        """Start Playwright browser"""
        logger.info("Starting Playwright browser...")
        self.playwright = sync_playwright().start()
        self.browser = self.playwright.chromium.launch(
            headless=True,  # Set to False for debugging
            args=['--disable-blink-features=AutomationControlled']
        )
        self.page = self.browser.new_page(
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        )
    
    def close_browser(self):
        """Close Playwright browser"""
        if self.page:
            self.page.close()
        if self.browser:
            self.browser.close()
        if self.playwright:
            self.playwright.stop()
    
    def search_google_news(self, query: str, max_results: int = 5) -> List[Dict]:
        """
        Search Google News for a specific query and return article URLs
        """
        logger.info(f"Searching Google News for: {query}")
        
        # Google News search URL
        search_url = f"https://news.google.com/search?q={query}&hl=en-US&gl=US&ceid=US:en"
        
        try:
            # Navigate to Google News search
            self.page.goto(search_url, timeout=30000, wait_until='networkidle')
            
            # Wait for articles to load
            self.page.wait_for_selector('article', timeout=10000)
            
            articles = []
            
            # Find all article elements
            article_elements = self.page.query_selector_all('article')
            
            for i, element in enumerate(article_elements[:max_results]):
                try:
                    # Find the main link within the article
                    link_element = element.query_selector('a')
                    if not link_element:
                        continue
                    
                    # Get article title from h3 or h4 tags
                    title_element = element.query_selector('h3') or element.query_selector('h4')
                    title = title_element.inner_text().strip() if title_element else f"Article {i+1}"
                    
                    # Get the href attribute
                    relative_url = link_element.get_attribute('href')
                    if not relative_url:
                        continue
                    
                    # Convert relative URL to absolute
                    if relative_url.startswith('./'):
                        article_url = f"https://news.google.com{relative_url[1:]}"
                    else:
                        article_url = urljoin("https://news.google.com", relative_url)
                    
                    # Try to find source/publication info
                    source_elements = element.query_selector_all('div')
                    source = "Unknown source"
                    for source_el in source_elements:
                        text = source_el.inner_text().strip()
                        # Look for text that looks like a publication name (short, contains letters)
                        if text and len(text) < 50 and re.search(r'[A-Za-z]', text) and not text.startswith('http'):
                            source = text
                            break
                    
                    articles.append({
                        'title': title,
                        'url': article_url,
                        'source': source,
                        'google_news_url': article_url
                    })
                    
                except Exception as e:
                    logger.warning(f"Error parsing article element {i}: {e}")
                    continue
            
            logger.info(f"Found {len(articles)} articles")
            return articles
            
        except Exception as e:
            logger.error(f"Error searching Google News: {e}")
            return []
    
    def get_actual_article_url(self, google_news_url: str) -> Optional[str]:
        """
        Follow Google News redirect to get the actual article URL
        """
        try:
            # Create a new page for URL resolution to avoid affecting main page
            context = self.browser.new_context()
            temp_page = context.new_page()
            
            # Navigate and get final URL after redirects
            temp_page.goto(google_news_url, timeout=15000)
            final_url = temp_page.url
            
            # Clean up
            temp_page.close()
            context.close()
            
            return final_url
        except Exception as e:
            logger.warning(f"Could not resolve actual URL for {google_news_url}: {e}")
            return None
    
    def scrape_article_content(self, url: str) -> Dict:
        """
        Scrape the full text content from an article URL using Playwright
        """
        logger.info(f"Scraping article: {url}")
        
        try:
            # Create a new context and page for article scraping
            context = self.browser.new_context()
            article_page = context.new_page()
            
            # Navigate to the article
            article_page.goto(url, timeout=20000, wait_until='domcontentloaded')
            
            # Wait a bit for content to load
            article_page.wait_for_timeout(2000)
            
            # Try common article content selectors
            content_selectors = [
                'article',
                '[role="article"]',
                '.article-content',
                '.post-content', 
                '.entry-content',
                '.story-body',
                '.article-body',
                'main',
                '.content',
                '.story-content'
            ]
            
            article_text = ""
            title = ""
            
            # Try to find the article title
            title_selectors = ['h1', '.headline', '.article-title', '.post-title', '.entry-title', '.story-headline']
            for selector in title_selectors:
                try:
                    title_element = article_page.query_selector(selector)
                    if title_element:
                        title = title_element.inner_text().strip()
                        if title:  # Only break if we got actual text
                            break
                except:
                    continue
            
            # Try to find article content
            for selector in content_selectors:
                try:
                    content_element = article_page.query_selector(selector)
                    if content_element:
                        # Get text content from paragraphs and divs
                        paragraphs = content_element.query_selector_all('p, div')
                        text_parts = []
                        for p in paragraphs:
                            text = p.inner_text().strip()
                            if text and len(text) > 10:  # Filter out very short text
                                text_parts.append(text)
                        article_text = ' '.join(text_parts)
                        
                        if len(article_text) > 100:  # Only use if substantial content found
                            break
                except:
                    continue
            
            # Fallback: get all paragraph text if no content container found
            if len(article_text) < 100:
                try:
                    paragraphs = article_page.query_selector_all('p')
                    text_parts = []
                    for p in paragraphs:
                        text = p.inner_text().strip()
                        if text and len(text) > 10:
                            text_parts.append(text)
                    article_text = ' '.join(text_parts)
                except:
                    pass
            
            # Clean up
            article_page.close()
            context.close()
            
            return {
                'url': url,
                'title': title or "No title found",
                'content': article_text,
                'word_count': len(article_text.split()) if article_text else 0,
                'success': len(article_text) > 0
            }
            
        except Exception as e:
            logger.error(f"Error scraping article {url}: {e}")
            return {
                'url': url,
                'title': "Error",
                'content': "",
                'word_count': 0,
                'success': False,
                'error': str(e)
            }
    
    def scrape_medicaid_news(self) -> List[Dict]:
        """
        Main method to scrape Medicaid Policy News articles
        """
        logger.info("Starting Medicaid Policy News scraping...")
        
        # Ensure browser is started
        if not self.browser:
            self.start_browser()
        
        # Search for articles
        articles = self.search_google_news("Medicaid Policy News", max_results=5)
        
        if not articles:
            logger.error("No articles found from Google News search")
            return []
        
        scraped_articles = []
        
        for i, article in enumerate(articles, 1):
            logger.info(f"Processing article {i}/5: {article['title']}")
            
            # Get the actual article URL
            actual_url = self.get_actual_article_url(article['google_news_url'])
            
            if actual_url and actual_url != article['google_news_url']:
                article['actual_url'] = actual_url
                content_data = self.scrape_article_content(actual_url)
            else:
                # If we can't get the actual URL, try scraping the Google News URL directly
                content_data = self.scrape_article_content(article['google_news_url'])
            
            # Combine article metadata with content
            final_article = {**article, **content_data}
            scraped_articles.append(final_article)
            
            # Be polite - add delay between requests
            time.sleep(3)
        
        return scraped_articles


def main():
    """
    Main function to run the scraper with Playwright
    """
    try:
        with GoogleNewsScraper() as scraper:
            articles = scraper.scrape_medicaid_news()
            
            if not articles:
                print("No articles were successfully scraped.")
                return
            
            print(f"\n{'='*80}")
            print(f"MEDICAID POLICY NEWS - TOP {len(articles)} ARTICLES")
            print(f"{'='*80}\n")
            
            for i, article in enumerate(articles, 1):
                print(f"ARTICLE {i}:")
                print(f"Title: {article['title']}")
                print(f"Source: {article.get('source', 'Unknown')}")
                print(f"URL: {article.get('actual_url', article.get('url', 'N/A'))}")
                print(f"Word Count: {article.get('word_count', 0)}")
                print(f"Scraped Successfully: {'Yes' if article.get('success', False) else 'No'}")
                
                if article.get('content'):
                    # Show first 500 characters of content
                    content_preview = article['content'][:500]
                    if len(article['content']) > 500:
                        content_preview += "..."
                    print(f"Content Preview:\n{content_preview}")
                
                if article.get('error'):
                    print(f"Error: {article['error']}")
                
                print(f"\n{'-'*60}\n")
            
            # Save to file
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            filename = f"medicaid_news_{timestamp}.txt"
            
            with open(filename, 'w', encoding='utf-8') as f:
                f.write(f"MEDICAID POLICY NEWS SCRAPING RESULTS (Powered by Playwright)\n")
                f.write(f"Scraped on: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"{'='*80}\n\n")
                
                for i, article in enumerate(articles, 1):
                    f.write(f"ARTICLE {i}:\n")
                    f.write(f"Title: {article['title']}\n")
                    f.write(f"Source: {article.get('source', 'Unknown')}\n")
                    f.write(f"URL: {article.get('actual_url', article.get('url', 'N/A'))}\n")
                    f.write(f"Word Count: {article.get('word_count', 0)}\n")
                    f.write(f"Content:\n{article.get('content', 'No content available')}\n")
                    f.write(f"\n{'='*80}\n\n")
            
            print(f"Results saved to: {filename}")
            
    except KeyboardInterrupt:
        print("\nScraping interrupted by user.")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    main()
