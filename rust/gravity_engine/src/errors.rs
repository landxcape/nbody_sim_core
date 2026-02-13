use thiserror::Error;

pub type Result<T> = std::result::Result<T, EngineError>;

#[derive(Debug, Error, PartialEq)]
pub enum EngineError {
    #[error("invalid config: {0}")]
    InvalidConfig(String),
    #[error("invalid body: {0}")]
    InvalidBody(String),
    #[error("duplicate body id: {0}")]
    DuplicateBodyId(String),
    #[error("body not found: {0}")]
    BodyNotFound(String),
    #[error("numerical instability: {0}")]
    NumericalInstability(String),
    #[error("schema validation failed: {0}")]
    SchemaValidationFailed(String),
    #[error("unsupported feature: {0}")]
    UnsupportedFeature(String),
}
