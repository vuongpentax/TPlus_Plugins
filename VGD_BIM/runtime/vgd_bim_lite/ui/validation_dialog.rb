module VGD; module BIM; module UI
  class ValidationDialog < Dialog
    def initialize(selection = false); super(selection ? 'validate_selection' : 'validate_model'); end
  end
end; end; end
