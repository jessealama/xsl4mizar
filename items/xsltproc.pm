package Xsltproc;

our @EXPORT = qw(apply_stylesheet);

sub apply_stylesheet {
  my $stylesheet = shift;
  my %parameters = %{shift ()};
  my $document = shift;
  my $result_path = shift;
  my $error_path = shift;

  my $params = '';
  foreach my $parameter (keys %parameters) {
    my $value = $parameters{$parameter};
    $params .= "--stringparam '${parameter}' '${value}' ";
  }

  my $xsltproc_invocation
    = defined $result_path
      ? (defined $error_path
	 ? "xsltproc $params $stylesheet $document > $result_path 2> $error_path"
	 : "xsltproc $params $stylesheet $document > $result_path 2> /dev/null")
      : (defined $error_path
	 ? "xsltproc $params $stylesheet $document > /dev/null 2> $error_path"
	 : "xsltproc $params $stylesheet $document > /dev/null 2> /dev/null");

  my $xsltproc_status = system ($xsltproc_invocation);
  my $xsltproc_exit_code = $xsltproc_status >> 8;

  if ($xsltproc_exit_code != 0) {
    if (defined $result_path) {
      if (defined $error_path) {
	croak ('Error: xsltproc did not exit cleanly applying the stylesheet at ', "\n", "\n", '  ', $stylesheet, "\n", "\n", 'to the document at', "\n", "\n", '  ', $document, ' .', "\n", "\n", 'with the parameters', "\n", "\n", '  ', $params, "\n", "\n", 'Its exit code was ', $xsltproc_exit_code, '.  The standard output and standard error streams were saved to', "\n", "\n", '  ', $result_path, "\n", "\n", 'and', "\n", "\n", '  ', $error_path, ' ,', "\n", "\n", 'respectively.');
      } else {
	croak ('Error: xsltproc did not exit cleanly applying the stylesheet at ', "\n", "\n", '  ', $stylesheet, "\n", "\n", 'to the document at', "\n", "\n", '  ', $document, ' .', "\n", "\n", 'with the parameters', "\n", "\n", '  ', $params, "\n", "\n", 'Its exit code was ', $xsltproc_exit_code, '.  The standard output was saved to', "\n", "\n", '  ', $result_path, "\n", "\n", 'but the standard error output was not saved.');
      }
    } else {
      if (defined $error_path) {
	croak ('Error: xsltproc did not exit cleanly applying the stylesheet at ', "\n", "\n", '  ', $stylesheet, "\n", "\n", 'to the document at', "\n", "\n", '  ', $document, ' .', "\n", "\n", 'with the parameters', "\n", "\n", '  ', $params, "\n", "\n", 'Its exit code was ', $xsltproc_exit_code, '.  The standard output was not saved, but the standard error streams were saved to', "\n", "\n", '  ', $error_path, ' .');
      } else {
	croak ('Error: xsltproc did not exit cleanly applying the stylesheet at ', "\n", "\n", '  ', $stylesheet, "\n", "\n", 'to the document at', "\n", "\n", '  ', $document, ' with the parameters', "\n", "\n", '  ', $params, ' .', "\n", "\n", 'Its exit code was ', $xsltproc_exit_code, '.  The standard output and standard error streams were not saved.');
      }
    }
  }
  return 1;
}

1; # I'm OK, you're OK
