use slint::{ComponentHandle, PlatformError};
use crate::{AboutWindow, ColourSchemeWindow, NewVersionWindow};

/// A dialog box that is to be shown centred over the main window.
pub trait CenteredDialog {
    fn show(&self) -> Result<(), PlatformError>;
    fn window(&self) -> &slint::Window;
    fn get_preferred_width(&self) -> f32;
    fn get_preferred_height(&self) -> f32;
    fn should_force_size(&self) -> bool;
    /// Focuses the dialog's initial element. Called after the dialog has been shown and
    /// positioned, because focusing a widget from Slint's `init` callback (or via
    /// `forward-focus`) does not work reliably: the window is not yet visible/focused at that
    /// point. Dialogs that don't need an initial focused element can use the default no-op.
    fn focus_initial_element(&self) {}
}

impl CenteredDialog for AboutWindow {
    fn show(&self) -> Result<(), PlatformError> {
        ComponentHandle::show(self)
    }
    fn window(&self) -> &slint::Window {
        ComponentHandle::window(self)
    }
    fn get_preferred_width(&self) -> f32 {
        self.get_preferred_w()
    }
    fn get_preferred_height(&self) -> f32 {
        self.get_preferred_h()
    }
    fn should_force_size(&self) -> bool {
        false
    }
}

impl CenteredDialog for ColourSchemeWindow {
    fn show(&self) -> Result<(), PlatformError> {
        ComponentHandle::show(self)
    }
    fn window(&self) -> &slint::Window {
        ComponentHandle::window(self)
    }
    fn get_preferred_width(&self) -> f32 {
        self.get_preferred_w()
    }
    fn get_preferred_height(&self) -> f32 {
        self.get_preferred_h()
    }
    fn should_force_size(&self) -> bool {
        false
    }
    fn focus_initial_element(&self) {
        self.invoke_focus_scheme_select();
    }
}

impl CenteredDialog for NewVersionWindow {
    fn show(&self) -> Result<(), PlatformError> {
        ComponentHandle::show(self)
    }
    fn window(&self) -> &slint::Window {
        ComponentHandle::window(self)
    }
    fn get_preferred_width(&self) -> f32 {
        self.get_preferred_w()
    }
    fn get_preferred_height(&self) -> f32 {
        self.get_preferred_h()
    }
    fn should_force_size(&self) -> bool {
        false
    }
    fn focus_initial_element(&self) {
        self.invoke_focus_open_release_button();
    }
}