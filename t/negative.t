use strict;

use Test::More;

use Image::Crop::CalibrationTarget;
use Digest::MD5 qw(md5_hex);

use File::Slurp qw(read_file write_file);

my $data = read_file('t/data/negative.jpg', { binmode => 'raw' });

my $crop = Image::Crop::CalibrationTarget->new( image_data => $data );

is(md5_hex($crop->image_data), '059729953abd47a2a3fbe889e88cf271', 'uncropped image data looks good');
isn't($crop->cropped, 1, 'image not to be cropped is not cropped');

done_testing;




