#
# Example RBAC DB.
# Replace with yours or import is as an external data bundle---e.g.
# by making OPA download a tarball from a Web server or by linking
# it from a local disk.
#

package httpbin.rbacdb

import data.authnz.http as http


# Role defs.
researchers := "researchers"
jeejee := "jeejee@teadal.eu"
sebs := "sebs@teadal.eu"

# Map each role to a list of permission objects.
# Each permission object specifies a set of allowed HTTP methods for
# the Web resources identified by the URLs matching the given regex.
role_based_permissions := {
    researchers: [
        {
            "methods": http.do_anything,
            "url_regex": "^/httpbin/anything/.*"
        },
    ]
}

user_based_permissions := {
    jeejee: [
        {
            "methods": http.do_anything,
            "url_regex": "^/httpbin/anything/.*"
        },
    ],
    sebs: [
        {
            "methods": http.read,
            "url_regex": "^/httpbin/anything/.*"
        }
    ]

}