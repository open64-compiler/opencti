# Known failures and result annotations

[Documentation home](index.md)

The web reports maintain known-failure annotations in cached data. An annotation classifies an observed failure for reporting; it does not make the test pass, change its expected output, or establish that the underlying defect is fixed.

## Add annotations

Open the known-failure editor from the failure report for the intended schedule/options set. The [editor CGI](../../www/cgi-bin/update_known_failures.cgi) requires the schedule, option identifier, and cache directory; use report-generated links so the context is correct.

- To add individual failures, enter comments in their fields and select Add.
- To include failures with identical error messages, choose the same-message add mode. The code collects messages from commented records and applies the associated comments to matching cached failures.
- To add by Perl regular expression, choose the pattern mode, enter a pattern, and comment exactly one seed failure. More than one comment in this mode is rejected. Matching entries receive the shared comment.
- The exact pattern `no core dump` has special handling for entries with no error-message field and assigns that same comment.

Pattern and same-message expansion can cover multiple log buckets in the day's cache, rather than just one visible test. Review the resulting set before relying on the classification. Annotation updates replace previous instances for related logs and record the comment date.

## Delete annotations

Select records and choose Delete. The editor supports deleting only the selected records, expanding by identical error message, or expanding by identical comment. These operations write the known-failure cache.

Matching in [CTI_lib.pm](../../lib/CTI_lib.pm) compares recorded error messages through `cmp_err_msg` when a message is present; otherwise it compares the error type. This allows some normalization of diagnostic text, so matching is not simply raw string equality in every reporting path.

[import_known_failures.pl](../../bin/www/import_known_failures.pl) copies classifications between schedules using `-from` and `-to`. Review its behavior and target cache before running it. Keep a backup when changing production classifications.
