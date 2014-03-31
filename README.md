# Image::Crop::CalibrationTarget

Crop out calibration targets in photographs of prints with calibration targets alongside.

## Synopsis

```perl
use File::Slurp qw(read_file write_file);

my $data = read_file('image.jpg', { binmode => 'raw' });

my $crop = Image::Crop::CalibrationTarget->new(
	image_data => $data,
	debug => 1,
);

write_file('/tmp/cropped_image.jpg', $crop->image_data);
```

## Methods

#### image_data

Cropped image data, or original image data if we found nothing to crop out.

#### cropped

Boolean to say whether we found a calibration target and cropped it out.

#### score

Relative score for this calibration target crop.

#### crop_orientation

Orientation of the crop; one of `top`, `right`, `bottom`, or `left`.

#### crop_percent

Percentage of pixels to crop from the given orientation.

## License

Copyright (c) David Chester <david@fmail.co.uk>

Available under the same terms as Perl itself.

