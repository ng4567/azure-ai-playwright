#!/usr/bin/env python3
"""
Conduent Contact Form Scraper
Scrapes form fields from the Conduent contact us page using Playwright
"""
from playwright.sync_api import sync_playwright
import json
import logging
from typing import List, Dict, Optional
from pathlib import Path
import sys
import os

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ContactFormScraper:
    def __init__(self, debug: bool = False):
        self.playwright = None
        self.browser = None
        self.page = None
        self.debug = debug
    
    def __enter__(self):
        """Context manager entry"""
        self.start_browser(headless=not self.debug)
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close_browser()
    
    def start_browser(self, headless: bool = True):
        """Start Playwright browser"""
        logger.info("Starting Playwright browser...")
        self.playwright = sync_playwright().start()
        self.browser = self.playwright.chromium.launch(
            headless=headless,  # Set to False for debugging
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
    
    def extract_field_info(self, element) -> Dict:
        """Extract comprehensive information about a form field"""
        try:
            field_info = {
                'tag_name': element.evaluate('el => el.tagName.toLowerCase()'),
                'type': element.get_attribute('type') or 'text',
                'name': element.get_attribute('name') or '',
                'id': element.get_attribute('id') or '',
                'placeholder': element.get_attribute('placeholder') or '',
                'value': element.get_attribute('value') or '',
                'required': element.get_attribute('required') is not None,
                'disabled': element.get_attribute('disabled') is not None,
                'readonly': element.get_attribute('readonly') is not None,
                'class': element.get_attribute('class') or '',
                'aria_label': element.get_attribute('aria-label') or '',
                'label': '',
                'options': []
            }
            
            # Get associated label
            label_text = self.find_label_for_field(element, field_info['id'], field_info['name'])
            if label_text:
                field_info['label'] = label_text
            
            # Handle select elements - get options
            if field_info['tag_name'] == 'select':
                options = element.query_selector_all('option')
                field_info['options'] = []
                for option in options:
                    option_info = {
                        'value': option.get_attribute('value') or '',
                        'text': option.inner_text().strip(),
                        'selected': option.get_attribute('selected') is not None
                    }
                    field_info['options'].append(option_info)
            
            # Handle textarea - get rows and cols
            if field_info['tag_name'] == 'textarea':
                field_info['rows'] = element.get_attribute('rows') or ''
                field_info['cols'] = element.get_attribute('cols') or ''
                field_info['value'] = element.inner_text().strip()
            
            # Handle input fields with specific attributes
            if field_info['tag_name'] == 'input':
                field_info['min'] = element.get_attribute('min') or ''
                field_info['max'] = element.get_attribute('max') or ''
                field_info['step'] = element.get_attribute('step') or ''
                field_info['pattern'] = element.get_attribute('pattern') or ''
                field_info['maxlength'] = element.get_attribute('maxlength') or ''
                field_info['minlength'] = element.get_attribute('minlength') or ''
                
                # For radio buttons and checkboxes
                if field_info['type'] in ['radio', 'checkbox']:
                    field_info['checked'] = element.get_attribute('checked') is not None
            
            return field_info
            
        except Exception as e:
            logger.warning(f"Error extracting field info: {e}")
            return {}
    
    def find_label_for_field(self, element, field_id: str, field_name: str) -> str:
        """Find the label associated with a form field"""
        try:
            # Try to find label by 'for' attribute matching field id
            if field_id:
                label_element = self.page.query_selector(f'label[for="{field_id}"]')
                if label_element:
                    return label_element.inner_text().strip()
            
            # Try to find parent label element
            parent_label = element.evaluate('''
                el => {
                    let parent = el.parentElement;
                    while (parent && parent.tagName.toLowerCase() !== 'label' && parent !== document.body) {
                        parent = parent.parentElement;
                    }
                    return parent && parent.tagName.toLowerCase() === 'label' ? parent.innerText.trim() : null;
                }
            ''')
            if parent_label:
                return parent_label
            
            # Try to find nearby text that might be a label
            nearby_text = element.evaluate('''
                el => {
                    // Look for previous sibling text
                    let prev = el.previousElementSibling;
                    if (prev && (prev.tagName.toLowerCase() === 'span' || 
                                prev.tagName.toLowerCase() === 'div' ||
                                prev.tagName.toLowerCase() === 'p')) {
                        let text = prev.innerText.trim();
                        if (text && text.length < 100) return text;
                    }
                    
                    // Look for text in parent element
                    let parent = el.parentElement;
                    if (parent) {
                        let text = '';
                        for (let child of parent.childNodes) {
                            if (child.nodeType === 3) { // Text node
                                text += child.textContent.trim() + ' ';
                            } else if (child.tagName && 
                                      (child.tagName.toLowerCase() === 'span' ||
                                       child.tagName.toLowerCase() === 'label')) {
                                text += child.innerText.trim() + ' ';
                            }
                        }
                        text = text.trim();
                        if (text && text.length < 100) return text;
                    }
                    return null;
                }
            ''')
            if nearby_text:
                return nearby_text
                
        except Exception as e:
            logger.debug(f"Error finding label: {e}")
        
        return ""
    
    def scrape_contact_form(self, url: str) -> List[Dict]:
        """
        Scrape all form fields from the Conduent contact page
        """
        logger.info(f"Scraping contact form from: {url}")
        
        try:
            # Navigate to the contact page
            self.page.goto(url, timeout=30000, wait_until='networkidle')
            
            # Wait for the page to fully load and any dynamic content
            self.page.wait_for_timeout(5000)
            
            # Try scrolling and interacting to trigger lazy loading of form elements
            logger.info("Scrolling and interacting to trigger form loading...")
            
            # Scroll down slowly in multiple steps to trigger lazy loading
            for i in range(5):
                scroll_position = (i + 1) * 200
                self.page.evaluate(f"window.scrollTo(0, {scroll_position})")
                self.page.wait_for_timeout(1000)
            
            # Scroll to bottom
            self.page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
            self.page.wait_for_timeout(5000)
            
            # Try clicking anywhere on the page to trigger interactions
            try:
                self.page.click('body')
                self.page.wait_for_timeout(2000)
            except:
                pass
            
            # Scroll back up to find forms
            self.page.evaluate("window.scrollTo(0, 0)")
            self.page.wait_for_timeout(3000)
            
            # Specifically wait for Marketo form to load
            logger.info("Waiting for Marketo form to fully load (up to 60 seconds)...")
            logger.info("NOTE: This may take a while - the form loads slowly. Please be patient...")
            
            form_loaded = False
            try:
                # Wait up to 60 seconds for Marketo form fields to appear
                self.page.wait_for_selector('input[name="FirstName"], input[name="Email"], select[name="InquiryType"]', timeout=60000)
                logger.info("✓ SUCCESS: Marketo form fields detected!")
                form_loaded = True
                # Extra wait for all fields to load
                self.page.wait_for_timeout(5000)
            except:
                logger.warning("Primary form fields not detected after 60s, trying alternative methods...")
                
                # Try waiting for any Marketo-related elements
                try:
                    logger.info("Looking for Marketo form container...")
                    self.page.wait_for_selector('.mktoForm, #mktoForm_1182, .mktoField', timeout=15000)
                    logger.info("✓ Found Marketo form container, waiting for all fields to populate...")
                    
                    # Wait and check periodically for form fields
                    for attempt in range(6):  # Check 6 times over 30 seconds
                        self.page.wait_for_timeout(5000)
                        fields_count = len(self.page.query_selector_all('input, select, textarea'))
                        logger.info(f"Attempt {attempt + 1}/6: Found {fields_count} total form elements")
                        if fields_count > 10:  # If we find more than just basic navigation
                            logger.info("✓ Form appears to be loaded with multiple fields!")
                            form_loaded = True
                            break
                            
                except:
                    logger.warning("No Marketo container found either, doing final long wait...")
                    logger.info("Waiting additional 30 seconds in case of very slow loading...")
                    # Final long wait in case everything loads very slowly
                    for i in range(6):
                        self.page.wait_for_timeout(5000)
                        logger.info(f"Final wait: {(i+1)*5}/30 seconds...")
            
            if form_loaded:
                logger.info("🎉 Form loading appears successful!")
            else:
                logger.warning("⚠️  Form may not have loaded completely, but proceeding with extraction...")
            
            # Take screenshot for debugging
            if self.debug:
                self.page.screenshot(path='conduent_contact_page_debug.png')
                logger.info("Screenshot saved: conduent_contact_page_debug.png")
            
            # Look for forms on the page
            forms = self.page.query_selector_all('form')
            logger.info(f"Found {len(forms)} form(s) on the page")
            
            all_fields = []
            
            # If no forms found, look for individual form elements
            if not forms:
                logger.info("No forms found, looking for individual form elements")
                form_selectors = [
                    'input[type="text"]', 'input[type="email"]', 'input[type="tel"]', 
                    'input[type="password"]', 'input[type="number"]', 'input[type="url"]',
                    'input[type="search"]', 'input[type="date"]', 'input[type="time"]',
                    'input[type="datetime-local"]', 'input[type="radio"]', 'input[type="checkbox"]',
                    'input[type="file"]', 'input[type="hidden"]', 'input[type="submit"]',
                    'input[type="button"]', 'input[type="reset"]', 'input:not([type])',
                    'textarea', 'select', 'button'
                ]
                
                for selector in form_selectors:
                    elements = self.page.query_selector_all(selector)
                    for element in elements:
                        field_info = self.extract_field_info(element)
                        if field_info:
                            all_fields.append(field_info)
            else:
                # Process each form
                for i, form in enumerate(forms):
                    logger.info(f"Processing form {i+1}")
                    
                    # Get form attributes
                    form_info = {
                        'form_index': i,
                        'form_action': form.get_attribute('action') or '',
                        'form_method': form.get_attribute('method') or 'get',
                        'form_id': form.get_attribute('id') or '',
                        'form_class': form.get_attribute('class') or ''
                    }
                    
                    # Find all form fields within this form
                    form_elements = form.query_selector_all('input, textarea, select, button')
                    
                    for element in form_elements:
                        field_info = self.extract_field_info(element)
                        if field_info:
                            # Add form context to field info
                            field_info.update(form_info)
                            all_fields.append(field_info)
            
            logger.info(f"Extracted {len(all_fields)} form fields")
            
            # Remove duplicates based on name and id
            unique_fields = []
            seen = set()
            for field in all_fields:
                identifier = (field.get('name', ''), field.get('id', ''), field.get('type', ''))
                if identifier not in seen:
                    seen.add(identifier)
                    unique_fields.append(field)
            
            logger.info(f"Found {len(unique_fields)} unique form fields")
            return unique_fields
            
        except Exception as e:
            logger.error(f"Error scraping contact form: {e}")
            return []


def main(debug: bool = False):
    """
    Main function to scrape the Conduent contact form
    """
    url = "https://www.conduent.com/contact-us/"
    
    try:
        with ContactFormScraper(debug=debug) as scraper:
            fields = scraper.scrape_contact_form(url)
            
            if not fields:
                print("No form fields were found on the page.")
                return
            
            # Create structured output
            result = {
                'url': url,
                'timestamp': '2025-01-21',
                'total_fields': len(fields),
                'fields': fields
            }
            
            # Print results as formatted JSON
            print(json.dumps(result, indent=2, ensure_ascii=False))
            
            # Save to file
            REPO_ROOT = Path(__file__).resolve().parent.parent
            OUTPUT_DIR = REPO_ROOT / "output"
            
            # Create output directory if it doesn't exist
            OUTPUT_DIR.mkdir(exist_ok=True)
            
            output_filename = 'conduent_contact_form_fields.json'
            output_file = OUTPUT_DIR / output_filename
            
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(result, f, indent=2, ensure_ascii=False)
            
            print(f"\nResults saved to: {output_file}")
            
            # Print summary
            print(f"\n{'='*60}")
            print(f"CONTACT FORM ANALYSIS SUMMARY")
            print(f"{'='*60}")
            print(f"URL: {url}")
            print(f"Total Fields Found: {len(fields)}")
            
            # Group by field type
            field_types = {}
            for field in fields:
                field_type = field.get('type', 'unknown')
                field_types[field_type] = field_types.get(field_type, 0) + 1
            
            print(f"\nField Types:")
            for field_type, count in sorted(field_types.items()):
                print(f"  - {field_type}: {count}")
            
            # Show required fields
            required_fields = [f for f in fields if f.get('required', False)]
            if required_fields:
                print(f"\nRequired Fields ({len(required_fields)}):")
                for field in required_fields:
                    name = field.get('name') or field.get('id') or 'unnamed'
                    label = field.get('label') or 'no label'
                    print(f"  - {name}: {label}")
            
    except KeyboardInterrupt:
        print("\nScraping interrupted by user.")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    # Allow debug mode via command line argument
    debug_mode = len(sys.argv) > 1 and sys.argv[1] == '--debug'
    main(debug=debug_mode)
    #remove the png file
    os.remove('conduent_contact_page_debug.png')