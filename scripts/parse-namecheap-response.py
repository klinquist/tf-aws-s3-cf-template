#!/usr/bin/env python3
"""Extract the small subset of Namecheap XML used by the setup scripts."""

import json
import sys
import xml.etree.ElementTree as ET


def local_name(tag):
    return tag.rsplit("}", 1)[-1]


def elements(root, name):
    return [element for element in root.iter() if local_name(element.tag) == name]


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: parse-namecheap-response.py XML_FILE MODE [ARGS...]")

    root = ET.parse(sys.argv[1]).getroot()
    mode = sys.argv[2]

    if mode == "errors":
        errors = []
        for element in elements(root, "Error"):
            message = (element.text or "").strip()
            if message:
                errors.append({"number": element.attrib.get("Number", ""), "message": message})
        print(json.dumps({"status": root.attrib.get("Status", ""), "errors": errors}))
        return

    if mode == "check":
        matches = elements(root, "DomainCheckResult")
        if not matches:
            raise SystemExit("Namecheap response did not include DomainCheckResult")
        print(json.dumps(matches[0].attrib))
        return

    if mode == "price":
        if len(sys.argv) != 5:
            raise SystemExit("price mode requires TLD and YEARS")
        tld = sys.argv[3].lower()
        years = sys.argv[4]
        for product in elements(root, "Product"):
            if product.attrib.get("Name", "").lower() != tld:
                continue
            for price in product:
                if local_name(price.tag) == "Price" and price.attrib.get("Duration") == years:
                    print(json.dumps(price.attrib))
                    return
        print("{}")
        return

    if mode == "registration":
        matches = elements(root, "DomainCreateResult")
        if not matches:
            raise SystemExit("Namecheap response did not include DomainCreateResult")
        print(json.dumps(matches[0].attrib))
        return

    raise SystemExit(f"unknown mode: {mode}")


if __name__ == "__main__":
    main()
