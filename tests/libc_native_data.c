#define _GNU_SOURCE
#include <ctype.h>
#include <iconv.h>
#include <pwd.h>
#include <search.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static int compare_ints(const void *left, const void *right) {
    int a = *(const int *)left;
    int b = *(const int *)right;
    return (a > b) - (a < b);
}

int main(void) {
    static const char text[] = "file2-file10";
    if (memrchr(text, 'f', sizeof text) != text + 6 ||
        strverscmp("file2", "file10") >= 0 ||
        !isupper('A') || isascii(0xa1) || toascii(0xa1) != '!') return 1;

    int values[3] = {8, 2, 0};
    int key = 5;
    size_t count = 2;
    if (lsearch(&key, values, &count, sizeof key, compare_ints) != &values[2] ||
        count != 3 || values[2] != key ||
        lfind(&key, values, &count, sizeof key, compare_ints) != &values[2]) return 2;

    static char record[] = "case:x:123:456:Case:/tmp:/bin/sh\n";
    FILE *stream = fmemopen(record, sizeof record - 1, "r");
    if (!stream) return 3;
    struct passwd *user = fgetpwent(stream);
    if (!user || user->pw_uid != 123 || user->pw_gid != 456 ||
        strcmp(user->pw_name, "case") || fclose(stream)) return 4;

    iconv_t converter = iconv_open("UTF-8", "ISO-8859-15");
    if (converter == (iconv_t)-1) return 5;
    char euro[1] = { (char)0xa4 };
    char converted[3];
    char *input = euro;
    char *output = converted;
    size_t remaining = sizeof euro;
    size_t available = sizeof converted;
    if (iconv(converter, &input, &remaining, &output, &available) != 0 ||
        remaining != 0 || available != 0 || memcmp(converted, "\xe2\x82\xac", 3) ||
        iconv_close(converter)) return 6;

    time_t epoch = 0;
    struct tm *utc = gmtime(&epoch);
    if (!utc || utc->tm_year != 70 || !utc->tm_zone || strcmp(utc->tm_zone, "UTC")) return 7;
    return 0;
}
