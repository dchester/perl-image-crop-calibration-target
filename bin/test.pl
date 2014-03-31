use strict;

use Crop;
use File::Slurp qw(read_file write_file);

my $filename = shift @ARGV;

my $contents = read_file($filename, { binmode => 'raw' });

my $crop = Crop->new(
	image_data => $contents,
	debug => 1,
);

my $image_data = $crop->image_data;

write_file('/tmp/out.jpg', { binmode => 'raw' }, $image_data);

print "cropped.\n" if $crop->cropped;

