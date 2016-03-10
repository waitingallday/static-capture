# Static Capture

From a starting URL, this script will download the site index and parse out any relative assets and links, continuing recursively through the captured pages until the entire (visible) site is statically captured. Relative links in CSS will be parsed as well.


Install:

`bundle`

Usage:

`rake capture source=https://web.unimelb.edu.au`
