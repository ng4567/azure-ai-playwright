"""
Conduent Contact Form Scraper
Scrapes form fields from the Conduent contact us page using Playwright
"""

from playwright.sync_api import sync_playwright
import json
import logging
from typing import List, Dict
from pathlib import Path

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
        """Start Playwright browser with enhanced stealth"""
        logger.info("Starting Playwright browser...")
        self.playwright = sync_playwright().start()
        
        # Enhanced browser args to avoid detection
        self.browser = self.playwright.chromium.launch(
            headless=headless,
            args=[
                '--disable-blink-features=AutomationControlled',
                '--disable-features=VizDisplayCompositor',
                '--no-first-run',
                '--disable-default-apps',
                '--disable-extensions',
                '--disable-web-security',
                '--disable-features=TranslateUI'
            ]
        )
        
        # Create context with realistic settings
        context = self.browser.new_context(
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            viewport={'width': 1920, 'height': 1080},
            locale='en-US',
            timezone_id='America/New_York'
        )
        
        self.page = context.new_page()
        
        # Add script to hide automation signs
        self.page.add_init_script("""
            delete window.navigator.webdriver;
            window.chrome = { runtime: {} };
            Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3] });
        """)
    
    def close_browser(self):
        """Close Playwright browser"""
        if self.page:
            context = self.page.context
            self.page.close()
            if context:
                context.close()
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
            self.page.wait_for_timeout(8000)
            
            # Try to interact with the page like a human
            logger.info("Simulating human interaction...")
            try:
                # Scroll down slowly to trigger form loading
                for i in range(3):
                    self.page.evaluate(f"window.scrollTo(0, {i * 500})")
                    self.page.wait_for_timeout(2000)
                
                # Try clicking on common elements that might reveal the form
                potential_triggers = [
                    'text="Contact Us"',
                    'text="Get in Touch"',
                    '[class*="contact"]',
                    '[id*="contact"]'
                ]
                
                for trigger in potential_triggers:
                    try:
                        elements = self.page.query_selector_all(trigger)
                        for element in elements:
                            if element.is_visible():
                                logger.info(f"Clicking potential trigger: {trigger}")
                                element.click()
                                self.page.wait_for_timeout(3000)
                                break
                    except:
                        continue
                        
            except Exception as e:
                logger.debug(f"Human interaction simulation error: {e}")
            
            # Look for buttons or elements that might trigger the form to appear
            form_triggers = [
                'button:has-text("Contact Us")',
                'button:has-text("Get in Touch")',
                'button:has-text("Contact")',
                'a:has-text("Contact Us")', 
                'a:has-text("Get in Touch")',
                '[class*="contact"][role="button"]',
                '[id*="contact"][role="button"]',
                '.btn-contact',
                '#contact-btn',
                '[data-toggle="form"]',
                '[data-action="show-form"]'
            ]
            
            for trigger_selector in form_triggers:
                try:
                    elements = self.page.query_selector_all(trigger_selector)
                    for element in elements:
                        if element.is_visible():
                            logger.info(f"Clicking form trigger: {trigger_selector}")
                            element.click()
                            self.page.wait_for_timeout(3000)
                            break
                except Exception as e:
                    logger.debug(f"Could not click {trigger_selector}: {e}")
                    continue
            
            # Try scrolling down to trigger lazy loading of form elements
            logger.info("Scrolling to bottom of page to trigger lazy loading...")
            self.page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
            self.page.wait_for_timeout(2000)
            
            # Scroll back up to find forms
            self.page.evaluate("window.scrollTo(0, 0)")
            self.page.wait_for_timeout(1000)
            
            # Wait for any dynamic content to load after interactions
            self.page.wait_for_timeout(3000)
            
            # Wait for contact form elements to appear
            logger.info("Waiting for Marketo contact form to appear...")
            try:
                # Specifically wait for Marketo form elements
                marketo_selectors = [
                    '#mktoForm_1182',  # The specific Marketo form ID we found before
                    '.mktoForm',       # Marketo form class
                    'input[name="FirstName"]',  # Expected field
                    'input[name="Email"]',      # Expected field
                    'select[name="InquiryType"]' # Expected dropdown
                ]
                
                form_found = False
                for selector in marketo_selectors:
                    try:
                        self.page.wait_for_selector(selector, timeout=10000)
                        logger.info(f"✓ Found Marketo form element: {selector}")
                        form_found = True
                        break
                    except:
                        continue
                
                if not form_found:
                    logger.warning("Marketo form not detected, trying generic form elements...")
                    # Fallback to generic form elements
                    form_element_selectors = [
                        'select', 'input[type="email"]', 'textarea', 
                        'input[placeholder*="email"]', 'input[name*="email"]',
                        'input[placeholder*="name"]', 'input[name*="name"]'
                    ]
                    
                    for selector in form_element_selectors:
                        try:
                            self.page.wait_for_selector(selector, timeout=5000)
                            logger.info(f"Found generic form elements: {selector}")
                            break
                        except:
                            continue
                        
                # Additional wait for dynamic content
                self.page.wait_for_timeout(3000)
                
            except Exception as e:
                logger.info(f"Form detection error: {e}")
            
            # Take screenshot for debugging
            if self.debug:
                self.page.screenshot(path='conduent_contact_page_debug.png')
                logger.info("Screenshot saved: conduent_contact_page_debug.png")
            
            # Look for forms on the page
            forms = self.page.query_selector_all('form')
            logger.info(f"Found {len(forms)} form(s) on the page")
            
            # Also check for iframes that might contain the contact form
            iframes = self.page.query_selector_all('iframe')
            logger.info(f"Found {len(iframes)} iframe(s) on the page")
            
            # Check each iframe for forms
            for i, iframe in enumerate(iframes):
                try:
                    iframe_content = iframe.content_frame()
                    if iframe_content:
                        iframe_forms = iframe_content.query_selector_all('form')
                        logger.info(f"Found {len(iframe_forms)} form(s) in iframe {i}")
                        forms.extend(iframe_forms)
                except Exception as e:
                    logger.debug(f"Could not access iframe {i}: {e}")
            
            # Debug: Print page content to understand what's available
            page_text = self.page.inner_text('body')
            if 'contact' in page_text.lower() or 'form' in page_text.lower():
                logger.info("Page contains contact/form-related content")
                # Look for specific contact form indicators
                contact_indicators = [
                    'Please provide the following information',
                    'contact form',
                    'get in touch',
                    'send us a message'
                ]
                for indicator in contact_indicators:
                    if indicator.lower() in page_text.lower():
                        logger.info(f"Found contact indicator: {indicator}")
            
            # Check for specific field patterns matching expected fields:
            # Inquiry Type, organization email, first name, last name, phone, job title, organization, country, business solution, tell us more
            standalone_selectors = [
                # Inquiry Type (dropdown)
                'select[name*="inquiry"]', 'select[id*="inquiry"]', 'select[class*="inquiry"]',
                'select[name*="type"]', 'select[id*="type"]', 'select[class*="type"]',
                
                # Organization email address  
                'input[type="email"]', 'input[name*="email"]', 'input[id*="email"]',
                'input[placeholder*="email"]', 'input[aria-label*="email"]',
                
                # First name
                'input[name*="first"]', 'input[id*="first"]', 'input[placeholder*="first"]',
                'input[name*="fname"]', 'input[id*="fname"]', 'input[placeholder*="fname"]', 
                'input[name*="firstname"]', 'input[id*="firstname"]',
                
                # Last name  
                'input[name*="last"]', 'input[id*="last"]', 'input[placeholder*="last"]',
                'input[name*="lname"]', 'input[id*="lname"]', 'input[placeholder*="lname"]',
                'input[name*="lastname"]', 'input[id*="lastname"]',
                
                # Phone number
                'input[type="tel"]', 'input[name*="phone"]', 'input[id*="phone"]',
                'input[placeholder*="phone"]', 'input[name*="tel"]', 'input[id*="tel"]',
                
                # Job title
                'input[name*="title"]', 'input[id*="title"]', 'input[placeholder*="title"]', 
                'input[name*="job"]', 'input[id*="job"]', 'input[placeholder*="job"]',
                'input[name*="position"]', 'input[id*="position"]',
                
                # Organization
                'input[name*="organization"]', 'input[id*="organization"]', 'input[placeholder*="organization"]',
                'input[name*="company"]', 'input[id*="company"]', 'input[placeholder*="company"]',
                'input[name*="org"]', 'input[id*="org"]', 'input[placeholder*="org"]',
                
                # Country (dropdown)
                'select[name*="country"]', 'select[id*="country"]', 'select[class*="country"]',
                'select[name*="location"]', 'select[id*="location"]',
                
                # Business solution (dropdown)
                'select[name*="solution"]', 'select[id*="solution"]', 'select[class*="solution"]',
                'select[name*="business"]', 'select[id*="business"]', 'select[class*="business"]',
                'select[name*="service"]', 'select[id*="service"]', 'select[class*="service"]',
                
                # Tell us more (textarea)
                'textarea[name*="message"]', 'textarea[id*="message"]', 'textarea[placeholder*="message"]',
                'textarea[name*="help"]', 'textarea[id*="help"]', 'textarea[placeholder*="help"]',
                'textarea[name*="more"]', 'textarea[id*="more"]', 'textarea[placeholder*="more"]',
                'textarea[name*="comment"]', 'textarea[id*="comment"]', 'textarea[placeholder*="comment"]',
                'textarea[name*="detail"]', 'textarea[id*="detail"]', 'textarea[placeholder*="detail"]',
                
                # Generic fallback selectors
                'input[type="text"]', 'select', 'textarea',
                'input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="checkbox"]):not([type="radio"])'
            ]
            
            standalone_fields = []
            for selector in standalone_selectors:
                try:
                    elements = self.page.query_selector_all(selector)
                    # Filter to only visible elements
                    visible_elements = [el for el in elements if el.is_visible()]
                    if visible_elements:
                        logger.info(f"Found {len(visible_elements)} visible elements for selector: {selector}")
                        standalone_fields.extend(visible_elements)
                except Exception as e:
                    logger.debug(f"Error with selector {selector}: {e}")
            
            # Remove duplicates
            unique_fields = []
            seen_elements = set()
            for field in standalone_fields:
                try:
                    # Create a unique identifier for the field
                    field_id = field.evaluate('''el => {
                        return el.tagName + '|' + (el.name || '') + '|' + (el.id || '') + '|' + (el.className || '');
                    }''')
                    if field_id not in seen_elements:
                        seen_elements.add(field_id)
                        unique_fields.append(field)
                except:
                    unique_fields.append(field)
            
            standalone_fields = unique_fields
            
            if standalone_fields:
                logger.info(f"Found {len(standalone_fields)} unique standalone contact-related fields")
                # Add these to forms list as pseudo-forms
                class PseudoForm:
                    def __init__(self, elements):
                        self.elements = elements
                    def query_selector_all(self, selector):
                        return self.elements
                    def get_attribute(self, attr):
                        return None
                
                forms.append(PseudoForm(standalone_fields))
            
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
            
            # Debug: Print field details to help understand what was found
            for i, field in enumerate(unique_fields):
                field_desc = f"Field {i+1}: {field.get('tag_name', 'unknown')} type='{field.get('type', '')}' name='{field.get('name', '')}' id='{field.get('id', '')}' placeholder='{field.get('placeholder', '')}' label='{field.get('label', '')}'"
                logger.info(field_desc)
            
            # Check specifically for all 10 expected fields
            expected_fields = {
                'inquiry_type': False,
                'organization_email': False, 
                'first_name': False,
                'last_name': False,
                'phone_number': False,
                'job_title': False,
                'organization': False,
                'country': False,
                'business_solution': False,
                'tell_us_more': False
            }
            
            for field in unique_fields:
                field_name = str(field.get('name', '')).lower()
                field_id = str(field.get('id', '')).lower()
                field_placeholder = str(field.get('placeholder', '')).lower()
                field_label = str(field.get('label', '')).lower()
                
                # Check for Inquiry Type dropdown
                if (field.get('tag_name') == 'select' and 
                    ('inquiry' in field_name or 'type' in field_name or 
                     'inquiry' in field_id or 'type' in field_id or
                     'inquiry' in field_label or 'type' in field_label)):
                    expected_fields['inquiry_type'] = True
                    logger.info("✓ Found Inquiry Type field")
                
                # Check for organization email
                if (field.get('type') == 'email' or 'email' in field_name or 'email' in field_id):
                    expected_fields['organization_email'] = True
                    logger.info("✓ Found Organization Email field")
                
                # Check for first name
                if (('first' in field_name and 'name' in field_name) or 'fname' in field_name or 'firstname' in field_name or
                    ('first' in field_id and 'name' in field_id) or 'fname' in field_id or 'firstname' in field_id or
                    ('first' in field_placeholder) or ('first' in field_label and 'name' in field_label)):
                    expected_fields['first_name'] = True
                    logger.info("✓ Found First Name field")
                
                # Check for last name
                if (('last' in field_name and 'name' in field_name) or 'lname' in field_name or 'lastname' in field_name or
                    ('last' in field_id and 'name' in field_id) or 'lname' in field_id or 'lastname' in field_id or
                    ('last' in field_placeholder) or ('last' in field_label and 'name' in field_label)):
                    expected_fields['last_name'] = True
                    logger.info("✓ Found Last Name field")
                
                # Check for phone number
                if (field.get('type') == 'tel' or 'phone' in field_name or 'tel' in field_name or 
                    'phone' in field_id or 'tel' in field_id or 'phone' in field_placeholder):
                    expected_fields['phone_number'] = True
                    logger.info("✓ Found Phone Number field")
                
                # Check for job title
                if (('title' in field_name and 'job' not in field_name) or 'job' in field_name or 'position' in field_name or
                    ('title' in field_id and 'job' not in field_id) or 'job' in field_id or 'position' in field_id or
                    'title' in field_placeholder or 'job' in field_placeholder):
                    expected_fields['job_title'] = True
                    logger.info("✓ Found Job Title field")
                
                # Check for organization
                if ('organization' in field_name or 'company' in field_name or 'org' in field_name or
                    'organization' in field_id or 'company' in field_id or 'org' in field_id or
                    'organization' in field_placeholder or 'company' in field_placeholder):
                    expected_fields['organization'] = True
                    logger.info("✓ Found Organization field")
                
                # Check for country dropdown
                if (field.get('tag_name') == 'select' and 
                    ('country' in field_name or 'location' in field_name or
                     'country' in field_id or 'location' in field_id or
                     'country' in field_label or 'location' in field_label)):
                    expected_fields['country'] = True
                    logger.info("✓ Found Country field")
                
                # Check for business solution dropdown
                if (field.get('tag_name') == 'select' and 
                    ('solution' in field_name or 'business' in field_name or 'service' in field_name or
                     'solution' in field_id or 'business' in field_id or 'service' in field_id or
                     'solution' in field_label or 'business' in field_label or 'service' in field_label)):
                    expected_fields['business_solution'] = True
                    logger.info("✓ Found Business Solution field")
                
                # Check for tell us more textarea
                if (field.get('tag_name') == 'textarea' and 
                    ('message' in field_name or 'help' in field_name or 'more' in field_name or 'comment' in field_name or
                     'message' in field_id or 'help' in field_id or 'more' in field_id or 'comment' in field_id or
                     'message' in field_placeholder or 'help' in field_placeholder or 'more' in field_placeholder)):
                    expected_fields['tell_us_more'] = True
                    logger.info("✓ Found Tell Us More field")
            
            found_count = sum(expected_fields.values())
            logger.info(f"Expected field detection: {expected_fields} ({found_count}/10 fields found)")
            
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
            output_filename = OUTPUT_DIR / 'conduent_contact_form_fields.json'
            with open(output_filename, 'w', encoding='utf-8') as f:
                json.dump(result, f, indent=2, ensure_ascii=False)
            
            print(f"\nResults saved to: {output_filename}")
            
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
    import sys
    # Allow debug mode via command line argument
    debug_mode = len(sys.argv) > 1 and sys.argv[1] == '--debug'
    main(debug=debug_mode)
