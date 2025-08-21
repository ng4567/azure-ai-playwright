import os

#check if json file with data exists ../output/conduent_contact_form_fields.json
assert os.path.exists('../output/conduent_contact_form_fields.json'), "conduent_contact_form_fields.json file does not exist, please run contact-form-scraper.py script first to generate the data!"

